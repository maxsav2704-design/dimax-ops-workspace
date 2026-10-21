import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

export async function checkTerms({ page, api, contract, save, expect, output, persisted = false }) {
  const path = '/api/v1/admin/accounting/contracts/' + contract.id + '/terms';
  await page.getByRole('button', { name: 'EN', exact: true }).click();
  await page.getByRole('tab', { name: 'Factory details and terms' }).click();
  const proof = persisted
    ? JSON.parse(await readFile(resolve(output, 'terms-proof.json'), 'utf8'))
    : { contract_id: contract.id, versions: [], bodies: [] };
  assert.equal(proof.contract_id, contract.id);
  if (!persisted) await expect(page.getByRole('combobox', { name: 'Terms history' })).toHaveValue('');
  for (const index of persisted ? [] : [0, 1]) {
    await page.getByRole('button', { name: 'New terms version' }).click();
    const form = page.getByRole('dialog');
    await expect(form.getByRole('button', { name: 'Save draft' })).toBeDisabled();
    if (index === 0) {
      for (const [label, value] of [
        ['Legal name', 'Synthetic Factory Legal Ltd'], ['Registration / tax number', 'TEST-123'],
        ['Registered address', 'Synthetic address, no real customer data'], ['Contact name', 'Test contact'],
        ['Contact email', 'contract@example.com'], ['Contact phone', '+972 50 000 0000'],
        ['Proposed start date', '2026-11-10'], ['Agreement reference', 'TEST ONLY - not an agreement'],
        ['Payment due terms', 'Synthetic: 30 calendar days after delivery of signed journals.'],
        ['Retention and release terms', 'Synthetic: no retention.'],
      ]) await form.getByLabel(label, { exact: true }).fill(value);
      await form.getByLabel('Installation payment basis', { exact: true }).selectOption('STAGES');
    } else {
      await expect(form.getByLabel('Legal name', { exact: true })).toHaveValue('Synthetic Factory Legal Ltd');
      await form.getByLabel('Registered address', { exact: true }).fill('Synthetic second address');
      await form.getByLabel('Retention and release terms', { exact: true }).fill('Synthetic: pending discussion, not an authorized withholding.');
    }
    await form.getByLabel('Change reason', { exact: true }).fill('Synthetic terms revision ' + (index + 1));
    const result = await save(path);
    assert.equal(result.row.version, index + 1);
    assert.equal(result.row.is_demo, true);
    assert.equal(result.row.usable_for_billing, false);
    assert.equal(result.row.factory_confirmed, false);
    proof.versions.push(result.row); proof.bodies.push(result.body);
    await expect(page.getByRole('combobox', { name: 'Terms history' })).toHaveValue(result.row.id);
  }
  if (!persisted) await writeFile(resolve(output, 'terms-proof.json'), JSON.stringify(proof, null, 2));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.getByRole('tab', { name: 'Factory details and terms' }).click();
  const selector = page.getByRole('combobox', { name: 'Terms history' });
  await expect(selector).toHaveValue(proof.versions[1].id);
  await selector.selectOption(proof.versions[0].id);
  await expect(page.getByText(proof.versions[0].address, { exact: true })).toBeVisible();
  const original = await api.get(path + '/' + proof.versions[0].id);
  assert.equal(original.status(), 200);
  assert.deepEqual(await original.json(), proof.versions[0]);
  await page.getByRole('button', { name: 'RU', exact: true }).click();
  await expect(page.getByRole('tab', { name: 'Реквизиты и условия' })).toHaveAttribute('aria-selected', 'true');
  await page.screenshot({ path: resolve(output, 'terms-ru.png'), fullPage: true });
  for (const value of [proof.versions[0].payment_terms, proof.versions[0].retention_terms]) {
    await page.getByText(value, { exact: true }).scrollIntoViewIfNeeded();
    await expect(page.getByText(value, { exact: true })).toBeVisible();
  }
  await page.screenshot({ path: resolve(output, 'terms-ru-conditions.png'), fullPage: true });
  await page.setViewportSize({ width: 768, height: 1000 });
  await page.getByRole('button', { name: 'עב', exact: true }).click();
  await page.getByRole('button', { name: 'גרסת תנאים חדשה' }).click();
  await expect(page.getByRole('dialog')).toHaveAttribute('dir', 'rtl');
  const box = await page.getByRole('dialog').boundingBox();
  assert.ok(box && box.x >= 0 && box.x + box.width <= 768 && box.y >= 0 && box.y + box.height <= 1001);
  await page.screenshot({ path: resolve(output, 'terms-he-768.png'), fullPage: true });
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeHidden();
  await page.getByRole('button', { name: 'EN', exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole('button', { name: 'EN', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.getByRole('button', { name: 'New terms version' })).toBeEnabled();
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);
  await page.screenshot({ path: resolve(output, 'terms-en-390.png'), fullPage: true });
  console.log('PASS: two real terms versions, immutable history' + (persisted ? ' after API restart' : ' after reload') + ', payment/retention clauses, RU/HE/390px, modal closure');
}
