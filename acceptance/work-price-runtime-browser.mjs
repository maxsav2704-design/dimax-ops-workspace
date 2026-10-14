import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";

const require = createRequire(resolve("dimax-operations-suite-main/package.json"));
const { chromium, expect } = require("@playwright/test");
const fixture = JSON.parse(await readFile("runtime-private/private-session.json", "utf8"));
async function settle(page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(document.getAnimations()
      .filter(animation => Number.isFinite(animation.effect?.getComputedTiming().endTime))
      .map(animation => animation.finished.catch(() => {})));
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
}
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, locale: "en-US" });
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.goto("http://127.0.0.1:4192/login");
  const form = page.locator('form.login-form[data-login-ready="true"]');
  await expect(form).toBeVisible({ timeout: 30000 });
  await form.locator("#company-id").fill(fixture.company);
  await form.locator("#email").fill(fixture.owner_email);
  await form.locator("#password").fill(fixture.password);
  const authenticated = page.waitForResponse(response =>
    response.url().includes("/api/v1/auth/login") && response.request().method() === "POST");
  await form.locator('button[type="submit"]').click();
  assert.equal((await authenticated).status(), 200);
  await expect(page).not.toHaveURL(/\/login/, { timeout: 30000 });
  const loaded = page.waitForResponse(response =>
    response.url().includes("/api/v1/admin/earnings/ledger") && response.request().method() === "GET");
  await page.goto("http://127.0.0.1:4192/earnings-ledger");
  const ledgerResponse = await loaded;
  assert.equal(ledgerResponse.status(), 200);
  const ledger = await ledgerResponse.json();
  assert.equal(ledger.items.length, 3);
  assert.equal(Math.round(ledger.items.reduce((sum, row) => sum + Number(row.amount_snapshot), 0) * 100), 1352);
  assert.ok(ledger.items.every(row => row.work_price && !row.can_correct));
  const visibleProject = page.getByText("Runtime acceptance site", { exact: true }).and(page.locator(":visible")).first();
  await expect(visibleProject).toBeVisible();
  await visibleProject.scrollIntoViewIfNeeded();
  await settle(page);
  await page.screenshot({ path: "runtime-private/ledger-desktop.png" });
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(visibleProject).toBeVisible();
  await visibleProject.scrollIntoViewIfNeeded();
  await settle(page);
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
  await page.screenshot({ path: "runtime-private/ledger-narrow.png" });
  assert.deepEqual(errors, []);
  console.log("PASS: real admin login, deployed ledger, immutable factory evidence, desktop/narrow layout");
} finally {
  await browser.close();
}
