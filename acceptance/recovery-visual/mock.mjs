// UI-only fault injection. No transport, persistence, credentials or business endpoints.
export const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const base = '/api/v1/admin/outbox/recovery';
export function createScenario(scenario = 'normal') {
  const row = { id: id(3), recovery_id: id(2), outbox_id: id(4), action: null, revision: 0 };
  const history = [], calls = [];
  let released = false, dropped = false;
  const fail = status => { throw Object.assign(new Error(`Synthetic ${status}`), { status }); };
  const request = async (path, init = {}, options = {}) => {
    calls.push({ path, method: init.method || 'GET', body: init.body });
    if (scenario === 'unavailable') fail(503);
    let data;
    if (init.method === 'POST') {
      if (path === `${base}/items/${id(3)}/decisions`) {
        const body = JSON.parse(init.body);
        if (scenario === 'conflict') fail(409);
        const existing = history.find(entry => entry.request_id === body.request_id);
        if (existing) data = existing;
        else {
          if (body.expected_revision !== row.revision) fail(409);
          row.action = body.action; row.revision += 1;
          data = { ...body, id: id(20 + history.length), item_id: row.id, revision: row.revision,
            actor_id: id(10), created_at: '2026-10-24T10:00:00Z' };
          history.push(data);
        }
        if (scenario === 'lost-response' && !dropped) { dropped = true; fail(0); }
      } else if (path === `${base}/release`) {
        if (!row.action) fail(409);
        released = true; data = {};
      } else throw new Error(`Forbidden synthetic write: ${path}`);
    } else if (path === base) data = { epoch: id(1), recovery_id: id(2), state: released ? 'RELEASED' : 'REVIEW',
      unresolved: row.action ? 0 : 1, held: row.action === 'HOLD' ? 1 : 0 };
    else if (path.startsWith(`${base}/items?`)) data = [{ ...row }];
    else if (path.startsWith(`${base}/decisions?`)) data = [...history];
    else if (path === `/api/v1/admin/outbox/${id(4)}`) data = {
      id: id(4), channel: 'EMAIL', recipient: 'factory@dimax.example', subject: 'Synthetic journal B-101',
      attachment_name: 'synthetic-journal.pdf', status: row.action === 'ACCEPTED' ? 'SENT' : 'PENDING',
      scheduled_at: '2026-10-24T08:00:00Z', sent_at: null,
    };
    else throw new Error(`Unmodelled endpoint (blocked): ${path}`);
    return options.schema ? options.schema.parse(data) : data;
  };
  return { request, calls, history };
}
const params = new URLSearchParams(globalThis.location?.search || '');
export const scenario = createScenario(params.get('scenario') || 'normal');
export const apiFetch = scenario.request;
export const logoutSession = async () => { throw new Error('No real session in synthetic preview'); };
export const getAccessToken = () => null;
