import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { checkTerms } from './commercial-terms-browser.mjs';

const require = createRequire(resolve('dimax-operations-suite-main/package.json'));
const { chromium, expect: baseExpect, request } = require('@playwright/test');
const expect = baseExpect.configure({ timeout: 60000 });
const output = process.env.DIMAX_COMMERCIAL_PROOF;
assert.ok(output, 'Set a disposable proof directory');
const fixture = JSON.parse(await readFile(resolve(output, 'private-session.json'), 'utf8'));
assert.equal(fixture.kind, 'dimax-commercial-runtime');
const UI = 'http://127.0.0.1:4194';
const API = 'http://127.0.0.1:8003';
const path = '/api/v1/admin/accounting/contracts';
const persisted = process.argv.includes('--persisted');
const probe = await request.newContext();
try {
  await expect.poll(async () => {
    try { return (await probe.get(API + '/ready', { timeout: 5000 })).status(); }
    catch { return 0; }
  }, { timeout: 180000, intervals: [1000, 2000, 5000] }).toBe(200);
} finally { await probe.dispose(); }
const browser = await chromium.launch({ channel: process.platform === 'win32' ? 'msedge' : undefined });
let api;
let page;
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
  const deniedRequests = [];
  // Safety guard only: every permitted API request reaches the real server.
  // No route.fulfill, fake response or auth dependency override is used.
  await context.route('**/api/v1/**', (route) => {
    if (new URL(route.request().url()).origin !== API) {
      deniedRequests.push(new URL(route.request().url()).origin);
      return route.abort();
    }
    return route.continue();
  });
  await context.addInitScript(() => localStorage.setItem('dimax_locale', 'en'));
  page = await context.newPage();
  page.setDefaultTimeout(60000);
  page.setDefaultNavigationTimeout(120000);
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(UI + '/login?next=%2Ffactory-accounting', { waitUntil: 'domcontentloaded' });
  const form = page.locator('form.login-form[data-login-ready="true"]');
  await expect(form).toBeVisible({ timeout: 120000 });
  await form.locator('#company-id').fill(fixture.users.OWNER.company_id);
  await form.locator('#email').fill(fixture.users.OWNER.email);
  await form.locator('#password').fill(fixture.password);
  const signingIn = page.waitForResponse((res) => res.url() === API + '/api/v1/auth/login' && res.request().method() === 'POST');
  await form.locator('button[type="submit"]').click();
  const login = await signingIn;
  assert.equal(login.status(), 200);
  console.log('Real login accepted');
  const token = (await login.json()).access_token;
  api = await request.newContext({ baseURL: API, extraHTTPHeaders: { Authorization: 'Bearer ' + token } });
  await expect(page.getByRole('heading', { level: 1, name: 'Factory settlements' })).toBeVisible({ timeout: 60000 });
  console.log('Commercial page visible');

  async function save(url) {
    const saving = page.waitForResponse((res) => res.url() === API + url && res.request().method() === 'POST');
    await page.getByRole('dialog').getByRole('button', { name: 'Save draft' }).click();
    const response = await saving;
    assert.equal(response.status(), 200);
    await expect(page.getByRole('dialog')).toBeHidden();
    return { row: await response.json(), body: response.request().postDataJSON() };
  }
  let proof;
  if (!persisted) {
    await expect(page.getByText('No contracts yet', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'New contract' }).click();
    let dialog = page.getByRole('dialog');
    await dialog.getByLabel('Factory', { exact: true }).fill('Synthetic Factory for DIMAX');
    await dialog.getByLabel('Contract reference').fill('DEMO-2026-11-LIVE');
    await dialog.getByLabel('Preparation reason').fill('Invented terms for isolated acceptance only');
    const contract = await save(path);
    console.log('Contract saved through the UI');
    proof = { contract: contract.row, contract_body: contract.body, prices: [], price_bodies: [] };
    const prices = path + '/' + contract.row.id + '/prices';
    for (const [index, amount] of ['400,50', '410'].entries()) {
      await page.getByRole('button', { name: 'New price version' }).click();
      dialog = page.getByRole('dialog');
      await dialog.getByLabel('Proposed start date').fill('2026-11-10');
      await dialog.getByLabel('Agreement reference').fill('TEST ONLY - no agreement');
      await dialog.getByLabel('Change reason').fill('Synthetic offer version ' + (index + 1));
      if (index === 0) {
        for (const [kind, id, stage] of [
          ['INSTALLATION', fixture.door_type, ''], ['STAGE', fixture.door_type, 'FRAME'], ['ADDON', fixture.addon, ''],
        ]) {
          await dialog.getByLabel('Pricing basis').selectOption(kind);
          await dialog.getByLabel('Select work').selectOption(id);
          if (stage) await dialog.getByLabel('Stage code').fill(stage);
          await dialog.getByRole('button', { name: 'Add line', exact: true }).click();
        }
        await dialog.getByLabel('DIMAX price, ILS excl. VAT: Acceptance entrance / FRAME', { exact: true }).fill('150');
        await dialog.getByLabel('DIMAX price, ILS excl. VAT: Acceptance adjustment', { exact: true }).fill('60');
      }
      await dialog.getByLabel('DIMAX price, ILS excl. VAT: Acceptance entrance', { exact: true }).fill(amount);
      const saved = await save(prices);
      console.log('Price version saved through the UI:', index + 1);
      proof.prices.push(saved.row);
      proof.price_bodies.push(saved.body);
      assert.equal(saved.row.version, index + 1);
      await expect(page.getByRole('combobox', { name: 'Price versions' })).toHaveValue(saved.row.id);
    }
    await page.getByRole('button', { name: 'New price version' }).click();
    await page.getByRole('dialog').getByLabel('Change reason').fill('Stale editor must not overwrite a competing version');
    const bodies = [1, 2].map((index) => ({ ...structuredClone(proof.price_bodies[1]),
      request_id: randomUUID(), expected_latest_version: 2, reason: 'Concurrent synthetic writer ' + index }));
    const replies = await Promise.all(bodies.map((data) => api.post(prices, { data })));
    assert.deepEqual(replies.map((res) => res.status()).sort(), [200, 409]);
    const winner = replies.findIndex((res) => res.status() === 200);
    proof.race_price = await replies[winner].json();
    proof.race_body = bodies[winner];
    const conflicting = page.waitForResponse((res) => res.url() === API + prices && res.request().method() === 'POST');
    await page.getByRole('dialog').getByRole('button', { name: 'Save draft' }).click();
    assert.equal((await conflicting).status(), 409);
    await expect(page.getByRole('dialog').getByRole('alert')).toContainText('Terms changed');
    await expect(page.getByRole('dialog').getByRole('button', { name: 'Save draft' })).toBeDisabled();
    await page.getByRole('dialog').getByRole('button', { name: 'Cancel' }).click();
    await page.getByRole('alertdialog').getByRole('button', { name: 'Close draft' }).click();
    await expect(page.getByRole('dialog')).toBeHidden();
    await writeFile(resolve(output, 'browser-proof.json'), JSON.stringify(proof, null, 2));
  } else {
    proof = JSON.parse(await readFile(resolve(output, 'browser-proof.json'), 'utf8'));
  }
  // A full reload proves the records come from PostgreSQL through the deployed API.
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { level: 1, name: 'Factory settlements' })).toBeVisible();
  const selector = page.getByRole('combobox', { name: 'Price versions' });
  await expect(selector).toHaveValue(proof.race_price.id);
  await selector.selectOption(proof.prices[0].id);
  await expect(page.getByRole('cell', { name: '400.50 ILS', exact: true })).toBeVisible();
  const original = await api.get(path + '/' + proof.contract.id + '/prices/' + proof.prices[0].id);
  assert.equal(original.status(), 200);
  assert.deepEqual(await original.json(), proof.prices[0]);
  await page.getByRole('button', { name: 'RU', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Расчёты с заводом' })).toBeVisible();
  await page.screenshot({ path: resolve(output, persisted ? 'persisted-ru.png' : 'live-ru.png'), fullPage: true });
  if (process.argv.includes('--terms')) await checkTerms({ page, api, contract: proof.contract, save, expect, output, persisted });
  assert.deepEqual(deniedRequests, []);
  assert.deepEqual(errors, []);
  console.log(persisted
    ? 'PASS: real browser login and immutable prices survive API restart'
    : 'PASS: real login, contract, full/stage/addon prices, two UI versions, concurrent HTTP writers, visible 409, reload');
} catch (error) {
  await page?.screenshot({ path: resolve(output, 'failure.png'), fullPage: true }).catch(() => {});
  const message = String(error.stack ?? error).replaceAll(fixture.password, '[redacted]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted-token]');
  console.error(message);
  process.exitCode = 1;
} finally {
  await api?.dispose();
  await browser.close();
}
