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
const project = 'dimax-approval-20261021';
function capture(mode) {
  const output = execFileSync('docker', ['compose', '-p', project, '-f', 'acceptance/commercial-runtime.compose.yml',
    '-f', 'acceptance/commercial-approval.compose.yml', 'exec', '-T', 'api', 'python', '/acceptance/approval.py', mode],
    { timeout: 300000, encoding: 'utf8', env: process.env });
  assert.match(output, /PASS:/);
}
const browser = await chromium.launch({ channel: process.platform === 'win32' ? 'msedge' : undefined });
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
  const errors = [], denied = [];
  await context.route('**/api/v1/**', (route) => {
    if (new URL(route.request().url()).origin !== API) { denied.push(route.request().url()); return route.abort(); }
    return route.continue();
  });
  await context.addInitScript(() => localStorage.setItem('dimax_locale', 'en'));
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
  await expect(dialog.getByText('Acceptance entrance', { exact: true })).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Send to factory' })).toBeDisabled();
  await dialog.getByRole('checkbox').check();
  await dialog.getByRole('button', { name: 'Send to factory' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText('Awaiting factory', { exact: true })).toBeVisible();
  await page.screenshot({ path: resolve(proof, 'approval-admin-en.png'), fullPage: true });
  console.log('PASS: real admin review and invitation, no recipient or price override');
  capture('link');
  const { token } = JSON.parse(await readFile(resolve(proof, 'private-link.json'), 'utf8'));
  // Keep the test host local; use the actual secret from locally captured mail.
  const factory = await context.newPage();
  factory.setDefaultTimeout(90000); factory.setDefaultNavigationTimeout(180000);
  factory.on('pageerror', (error) => errors.push(error.message));
  await factory.goto(UI + '/commercial-approval#' + token, { waitUntil: 'domcontentloaded' });
  await expect(factory.getByText('Acceptance entrance', { exact: true })).toBeVisible();
  assert.equal(new URL(factory.url()).hash, '');
  await factory.getByRole('button', { name: 'Email a verification code' }).click();
  await expect(factory.getByText(/Code email queued/)).toBeVisible();
  capture('code');
  const { code } = JSON.parse(await readFile(resolve(proof, 'private-code.json'), 'utf8'));
  await factory.getByLabel('Your full name').fill('Synthetic Representative');
  await factory.getByLabel('Code from email').fill(code);
  await factory.getByRole('checkbox').check();
  await factory.getByRole('button', { name: 'Confirm both versions' }).click();
  await expect(factory.getByText('Factory decision recorded', { exact: true })).toBeVisible();
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
  await expect(page.getByRole('dialog').getByText('Acceptance entrance', { exact: true })).toBeVisible();
  assert.deepEqual(errors, []); assert.deepEqual(denied, []);
  capture('verify');
  console.log('PASS: factory mailbox decision, admin receipt, RU390/HE768 and exact-version history');
} finally { await browser.close(); }
