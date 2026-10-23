import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const require = createRequire(resolve('dimax-operations-suite-main/package.json'));
const { chromium, expect: baseExpect } = require('@playwright/test');
const expect = baseExpect.configure({ timeout: 90000 });
const proof = process.env.DIMAX_COMMERCIAL_PROOF;
assert.ok(proof);
const fixture = JSON.parse(await readFile(resolve(proof, 'private-session.json'), 'utf8'));
assert.equal(fixture.kind, 'dimax-commercial-runtime');
const UI = 'http://127.0.0.1:4194', API = 'http://127.0.0.1:8003';
const project = process.env.DIMAX_COMMERCIAL_PROJECT;
assert.match(project ?? '', /^dimax-approval-[a-z0-9-]+$/, 'Explicit isolated Compose project required');
function capture(mode) {
  const mailpit = process.env.DIMAX_COMMERCIAL_MAILPIT === '1'
    ? ['-f', 'acceptance/commercial-approval-mailpit.compose.yml'] : [];
  const output = execFileSync('docker', ['compose', '-p', project, '-f', 'acceptance/commercial-runtime.compose.yml',
    '-f', 'acceptance/commercial-approval.compose.yml', ...mailpit, 'exec', '-T', 'api', 'python', '/acceptance/approval.py', mode],
    { timeout: 300000, encoding: 'utf8', env: process.env });
  assert.match(output, /PASS:/);
}
const browser = await chromium.launch({ channel: process.platform === 'win32' ? 'msedge' : undefined });
try {
  const errors = [], denied = [];
  async function isolatedContext() {
    const isolated = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
    await isolated.route('**/*', (route) => {
      const url = new URL(route.request().url());
      if (![UI, API].includes(url.origin)) { denied.push(url.origin + url.pathname); return route.abort(); }
      return route.continue();
    });
    await isolated.addInitScript(() => localStorage.setItem('dimax_locale', 'en'));
    return isolated;
  }
  const context = await isolatedContext();
  const page = await context.newPage();
  page.on('pageerror', (error) => errors.push(error.message));
  page.setDefaultTimeout(90000); page.setDefaultNavigationTimeout(180000);
  await page.goto(UI + '/login?next=%2Ffactory-accounting', { waitUntil: 'domcontentloaded' });
  const form = page.locator('form.login-form[data-login-ready="true"]');
  await expect(form).toBeVisible({ timeout: 180000 });
  await form.locator('#company-id').fill(fixture.users.OWNER.company_id);
  await form.locator('#email').fill(fixture.users.OWNER.email);
  await form.locator('#password').fill(fixture.password);
  await form.locator('button[type="submit"]').click();
  await page.getByRole('tab', { name: 'Factory confirmation', exact: true }).click();
  await expect(page.getByText('No invitations yet')).toBeVisible();
  await page.getByRole('button', { name: 'Review latest versions' }).click();
  await page.getByRole('button', { name: 'Send to factory', exact: true }).click();
  const dialog = page.getByRole('dialog');
  const installationRow = (scope) => scope.getByRole('row').filter({ hasText: 'Acceptance entrance' });
  await expect(installationRow(dialog)).toHaveCount(1);
  await expect(installationRow(dialog)).toContainText('400.50');
  await expect(dialog.getByRole('button', { name: 'Send to factory' })).toBeDisabled();
  await dialog.getByRole('checkbox').check();
  const invitationResponse = page.waitForResponse((response) =>
    response.url().startsWith(API) && response.url().endsWith('/approvals') && response.request().method() === 'POST');
  await dialog.getByRole('button', { name: 'Send to factory' }).click();
  const invitation = await (await invitationResponse).json();
  for (const key of ['token', 'verification_code', 'approval_url', 'secret']) assert.equal(key in invitation, false);
  await expect(dialog).toBeHidden();
  await expect(page.getByText('Awaiting factory', { exact: true })).toBeVisible();
  await page.screenshot({ path: resolve(proof, 'approval-admin-en.png'), fullPage: true });
  console.log('PASS: real admin review and invitation, no recipient or price override');
  capture('link');
  const { token } = JSON.parse(await readFile(resolve(proof, 'private-link.json'), 'utf8'));
  // Keep the test host local; use the actual secret from locally captured mail.
  const factoryContext = await isolatedContext();
  const factory = await factoryContext.newPage();
  const publicRequests = [];
  factory.on('request', (request) => {
    if (request.url().startsWith(API + '/api/v1/public/commercial-approvals/')) publicRequests.push(request);
  });
  factory.setDefaultTimeout(90000); factory.setDefaultNavigationTimeout(180000);
  factory.on('pageerror', (error) => errors.push(error.message));
  await factory.goto(UI + '/commercial-approval#' + token, { waitUntil: 'domcontentloaded' });
  await expect(factory.locator('meta[name="referrer"]')).toHaveAttribute('content', 'no-referrer');
  await expect(installationRow(factory)).toHaveCount(1);
  await expect(installationRow(factory)).toContainText('400.50');
  await expect(factory.getByRole('button', { name: 'Confirm both versions' })).toBeDisabled();
  assert.equal(new URL(factory.url()).hash, '');
  await factory.screenshot({ path: resolve(proof, 'approval-public-en-review.png'), fullPage: true });
  await factory.setViewportSize({ width: 390, height: 844 });
  await factory.getByRole('button', { name: 'Русский', exact: true }).click();
  await expect(factory.getByRole('button', { name: 'Подтвердить обе версии' })).toBeDisabled();
  await expect.poll(() => factory.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await factory.screenshot({ path: resolve(proof, 'approval-public-ru-form-390.png'), fullPage: true });
  await factory.getByRole('button', { name: 'English', exact: true }).click();
  await factory.setViewportSize({ width: 1440, height: 1000 });
  await factory.getByRole('button', { name: 'Email a verification code' }).click();
  await expect(factory.getByText(/Code email queued/)).toBeVisible();
  capture('code');
  const { code } = JSON.parse(await readFile(resolve(proof, 'private-code.json'), 'utf8'));
  await factory.getByLabel('Your full name').fill('Synthetic Representative');
  await factory.getByLabel('Code from email').fill(code === '000000' ? '111111' : '000000');
  await expect(factory.getByRole('button', { name: 'Confirm both versions' })).toBeDisabled();
  await factory.getByRole('checkbox').check();
  const rejected = factory.waitForResponse((response) => response.url() === API + '/api/v1/public/commercial-approvals/confirm');
  await factory.getByRole('button', { name: 'Confirm both versions' }).click();
  assert.equal((await rejected).status(), 403);
  await expect(factory.getByRole('alert')).toContainText('Code incorrect or expired');
  await factory.getByLabel('Code from email').fill(code);
  const confirmed = factory.waitForResponse((response) => response.url() === API + '/api/v1/public/commercial-approvals/confirm');
  await factory.getByRole('button', { name: 'Confirm both versions' }).click();
  const decisionResponse = await confirmed;
  assert.equal(decisionResponse.status(), 200);
  assert.equal(decisionResponse.headers()['cache-control'], 'no-store');
  const decision = await decisionResponse.json();
  await expect(factory.getByText('Factory decision recorded', { exact: true })).toBeVisible();
  assert.deepEqual(await factoryContext.cookies(), []);
  for (const request of publicRequests) {
    const headers = await request.allHeaders();
    assert.equal(headers.authorization, undefined);
    assert.equal(headers.cookie, undefined);
    assert.equal(headers.referer, undefined);
  }
  const payload = { token, terms_version: decision.snapshot.terms.version, price_version: decision.snapshot.price.version,
    snapshot_hash: decision.snapshot_hash, signer_name: 'Synthetic Representative', accepted: true, verification_code: code };
  const replay = await factoryContext.request.post(API + '/api/v1/public/commercial-approvals/confirm', { data: payload });
  assert.equal(replay.status(), 200);
  assert.deepEqual(await replay.json(), decision);
  for (const changed of [{ signer_name: 'Another Representative' }, { price_version: payload.price_version + 1 }]) {
    const response = await factoryContext.request.post(API + '/api/v1/public/commercial-approvals/confirm', { data: { ...payload, ...changed } });
    assert.equal(response.status(), 409);
  }
  const newCode = await factoryContext.request.post(API + '/api/v1/public/commercial-approvals/request-code', { data: { token } });
  assert.equal(newCode.status(), 409);
  const invalidToken = (token[0] === 'A' ? 'B' : 'A') + token.slice(1);
  const invalidPreview = await factoryContext.request.post(API + '/api/v1/public/commercial-approvals/preview', { data: { token: invalidToken } });
  assert.equal(invalidPreview.status(), 404);
  console.log('PASS: anonymous factory context, explicit consent, wrong-code rejection and immutable replay');
  await factory.setViewportSize({ width: 390, height: 844 });
  await factory.getByRole('button', { name: 'Русский', exact: true }).click();
  await expect(factory.getByRole('heading', { name: 'Согласование коммерческого договора' })).toBeVisible();
  await expect.poll(() => factory.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await factory.screenshot({ path: resolve(proof, 'approval-public-ru-390.png'), fullPage: true });
  await factory.setViewportSize({ width: 768, height: 1024 });
  await factory.getByRole('button', { name: 'עברית', exact: true }).click();
  await expect(factory.getByRole('main')).toHaveAttribute('dir', 'rtl');
  await expect.poll(() => factory.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await factory.screenshot({ path: resolve(proof, 'approval-public-he-768.png'), fullPage: true });
  await page.getByRole('region', { name: 'Factory confirmation', exact: true })
    .getByRole('button', { name: 'Refresh', exact: true }).click();
  await expect(page.getByText('Confirmed', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'View exact versions' }).click();
  await expect(installationRow(page.getByRole('dialog'))).toHaveCount(1);
  await expect(installationRow(page.getByRole('dialog'))).toContainText('400.50');
  assert.deepEqual(errors, []); assert.deepEqual(denied, []);
  capture('verify');
  console.log('PASS: factory mailbox decision, admin receipt, RU390/HE768 and exact-version history');
} finally { await browser.close(); }
