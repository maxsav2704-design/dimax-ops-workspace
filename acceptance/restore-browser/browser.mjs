import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

assert.equal(process.env.GITHUB_ACTIONS, 'true');
assert.equal(process.env.DIMAX_RESTORE_BROWSER, 'synthetic-only');
const require = createRequire(path.resolve('inputs/frontend/package.json'));
const { chromium, expect } = require('@playwright/test');
const work = process.argv[2];
const fixture = JSON.parse(fs.readFileSync(path.join(work, 'browser-fixture.json'), 'utf8'));
const prior = JSON.parse(fs.readFileSync(path.join(work, 'browser-prior-smtp.json'), 'utf8'));
const api = 'http://127.0.0.1:18090';
const origin = 'http://127.0.0.1:4196';
const prefix = '/api/v1/admin/outbox/recovery';
const browser = await chromium.launch({ headless: true });
const contexts = [];
const writes = [];
const failures = [];

async function control(command, expected) {
  const response = await fetch('http://127.0.0.1:18091/' + command, { method: 'POST', signal: AbortSignal.timeout(60000) });
  assert.equal(response.status, 200, await response.clone().text());
  const result = await response.json();
  if (expected !== undefined) assert.equal(result.processed, expected);
  return result;
}

async function confirmCommand(page, button, reason) {
  await page.getByRole('button', { name: button, exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Reason', { exact: true }).fill(reason);
  await dialog.getByLabel('I confirm this recovery action.', { exact: true }).check();
  const response = page.waitForResponse(res => res.url().startsWith(api + prefix) && res.request().method() === 'POST');
  await dialog.getByRole('button', { name: 'Confirm', exact: true }).click();
  assert.equal((await response).status(), 200);
  await expect(dialog).toBeHidden();
}

async function fillDecision(page, message, action) {
  await page.getByRole('row').filter({ hasText: message.payload.subject }).getByRole('button', { name: 'Review', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('combobox', { name: 'Decision', exact: true }).selectOption(action);
  await dialog.getByLabel('Reason', { exact: true }).fill('Synthetic restore: original provider capture reconciled');
  await dialog.getByLabel('Evidence reference', { exact: true }).fill(action === 'ACCEPTED' ? `SOURCE-SMTP-${message.id}` : `SYNTHETIC-REVIEW-${message.id}`);
  if (action === 'ACCEPTED') {
    await dialog.getByLabel('Provider acceptance time', { exact: true }).fill(new Date(prior.accepted_at).toISOString().slice(0, 16));
    await dialog.getByRole('combobox', { name: 'UTC offset', exact: true }).selectOption('+00:00');
  }
  await dialog.getByLabel('I checked the message, recipient and evidence.', { exact: true }).check();
  return dialog;
}

try {
  assert.deepEqual((await control('tick', 0)).received, []);
  let heldPage;
  const held = fixture.messages.find(message => message.status === 'FAILED');
  for (const [index, account] of fixture.accounts.entries()) {
    const context = await browser.newContext({ viewport: { width: 1366, height: 1000 } });
    contexts.push(context);
    const page = await context.newPage();
    page.on('pageerror', error => failures.push(error.message));
    page.on('request', request => {
      const url = new URL(request.url());
      if (url.pathname.startsWith('/api/v1/') && request.method() === 'POST') writes.push(url.pathname);
    });
    await page.addInitScript(() => localStorage.setItem('dimax_locale', 'en'));
    await page.goto(origin + '/login?next=%2Foperations%2Frecovery');
    const form = page.locator('form.login-form[data-login-ready="true"]');
    await expect(form).toBeVisible({ timeout: 30000 });
    await form.locator('#company-id').fill(account.company_id);
    await form.locator('#email').fill(account.email);
    await form.locator('#password').fill('Synthetic-CI-only-42!');
    await form.locator('button[type="submit"]').click();
    await expect(page.getByRole('heading', { name: 'Mail reconciliation', exact: true })).toBeVisible({ timeout: 30000 });
    await confirmCommand(page, 'Open review', 'Synthetic disaster: original DB and storage removed, backup restored');
    await expect(page.getByRole('button', { name: 'Resume queue', exact: true })).toBeDisabled();
    assert.deepEqual((await control('tick', 0)).received, []);
    const messages = fixture.messages.filter(message => message.company_id === account.company_id && message.status !== 'SENT');
    for (const message of messages) {
      const action = prior.ids.includes(message.id) ? 'ACCEPTED' : message.status === 'FAILED' ? 'HOLD' : 'RETRY';
      const dialog = await fillDecision(page, message, action);
      const response = page.waitForResponse(res => res.url().includes(prefix + '/items/') && res.request().method() === 'POST');
      await dialog.getByRole('button', { name: 'Record decision', exact: true }).click();
      assert.equal((await response).status(), 200);
      await expect(dialog).toBeHidden();
    }
    await confirmCommand(page, 'Resume queue', 'All disputed messages reviewed; unresolved delivery remains on HOLD');
    await expect(page.getByRole('heading', { name: 'Queue released', exact: true })).toBeVisible();
    assert.deepEqual((await control('tick', 0)).received, []);
    await page.screenshot({ path: `evidence/restore-company-${index + 1}.png`, fullPage: true });
    if (held.company_id === account.company_id) heldPage = page;
  }
  assert(heldPage, 'Held message must be available to the owning company');
  const dialog = await fillDecision(heldPage, held, 'RETRY');
  let committedRequest;
  let lostResponse = false;
  await heldPage.route('**/api/v1/admin/outbox/recovery/items/*/decisions', async route => {
    if (!lostResponse) {
      committedRequest = route.request().postData();
      const result = await route.fetch();
      assert.equal(result.status(), 200);
      lostResponse = true;
      await route.abort('failed');
    } else {
      assert.equal(route.request().postData(), committedRequest, 'Retry changed the idempotent decision');
      await route.continue();
    }
  });
  await dialog.getByRole('button', { name: 'Record decision', exact: true }).click();
  const retry = dialog.getByRole('button', { name: 'Retry the same decision', exact: true });
  await expect(retry).toBeEnabled({ timeout: 15000 });
  await expect(dialog.getByLabel('Reason', { exact: true })).toBeDisabled();
  await retry.click();
  await expect(dialog).toBeHidden();
  const delivered = await control('tick', 1);
  assert.deepEqual(delivered.received, [held.id]);
  assert.deepEqual((await control('tick', 0)).received, [held.id]);
  await heldPage.getByRole('tab', { name: 'Decision history', exact: true }).click();
  await expect(heldPage.getByRole('tabpanel').getByRole('article')).toHaveCount(4);
  await heldPage.screenshot({ path: 'evidence/restore-decision-history.png', fullPage: true });
  assert.equal((await control('verify')).passed, true);
  assert(writes.every(url => url.startsWith(prefix) || url.startsWith('/api/v1/auth/')), 'Unexpected business endpoint write');
  assert.deepEqual(failures, []);
  console.log('PASS: browser OWNER reviews/release, held retry, lost-response idempotency, exact restored PDF, zero business writes');
} finally {
  for (const context of contexts) await context.close();
  await browser.close();
}
