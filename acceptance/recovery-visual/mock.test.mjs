import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createScenario, id } from './mock.mjs';
const base = '/api/v1/admin/outbox/recovery';
const body = { request_id: id(9), expected_revision: 0, action: 'HOLD', reason: 'Synthetic review', evidence: 'TEST-1', accepted_at: null };
const post = { method: 'POST', body: JSON.stringify(body) };
test('unmodelled endpoints, including business writes, fail closed', async () => {
  const model = createScenario();
  await assert.rejects(model.request('/api/v1/doors/1/install', post));
  await assert.rejects(model.request('http://localhost:8000/health'));
  assert.equal(model.history.length, 0);
});
test('cannot resume unresolved synthetic messages; HOLD survives release', async () => {
  const model = createScenario();
  await assert.rejects(model.request(base + '/release', post), { status: 409 });
  await model.request(base + '/items/' + id(3) + '/decisions', post);
  await model.request(base + '/release', post);
  assert.deepEqual(await model.request(base), { epoch: id(1), recovery_id: id(2), state: 'RELEASED', unresolved: 0, held: 1 });
});
test('lost-response scenario commits once and permits identical retry', async () => {
  const model = createScenario('lost-response');
  const path = base + '/items/' + id(3) + '/decisions';
  await assert.rejects(model.request(path, post), { status: 0 });
  await model.request(path, post);
  assert.equal(model.history.length, 1);
});
test('conflict and unavailable scenarios never record a decision', async () => {
  for (const scenario of ['conflict', 'unavailable']) {
    const model = createScenario(scenario);
    await assert.rejects(model.request(base + '/items/' + id(3) + '/decisions', post));
    assert.equal(model.history.length, 0);
  }
});
