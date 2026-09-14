import assert from "node:assert/strict";
import http from "node:http";
import { once } from "node:events";
import { test } from "node:test";
import { createSyncAckRelay } from "./acceptance-sync-relay.mjs";

const scope = { companyId: "test-company", userId: "test-user", projectId: "test-project", doorId: "test-door" };
const event = {
  client_event_id: "retained-event", type: "DOOR_SET_STATUS", project_id: scope.projectId,
  happened_at: "2026-09-14T10:00:00Z", payload: { door_id: scope.doorId, status: "INSTALLED", previous_version: 0 },
};
const auth = (claims = { company_id: scope.companyId, sub: scope.userId }) =>
  `Bearer header.${Buffer.from(JSON.stringify(claims)).toString("base64url")}.test-signature`;

async function harness(t, handler) {
  const upstream = http.createServer(handler);
  upstream.listen(0, "127.0.0.1");
  await once(upstream, "listening");
  const events = [];
  const relay = createSyncAckRelay({ upstreamPort: upstream.address().port, scope, onEvent: (item) => events.push(item) });
  relay.listen(0, "127.0.0.1");
  await once(relay, "listening");
  t.after(async () => {
    await Promise.all([relay, upstream].map((server) => new Promise((resolve) => {
      server.close(resolve);
      server.closeAllConnections();
    })));
  });
  return {
    events,
    send: (items = [event], token = auth(), path = "/api/v1/installer/sync") => fetch(`http://127.0.0.1:${relay.address().port}${path}`, {
      method: "POST", headers: { Authorization: token, "Content-Type": "application/json" },
      body: JSON.stringify({ events: items }), signal: AbortSignal.timeout(3000),
    }),
  };
}

function respond(request, response, { status = 200, ok = true, applied = true } = {}, onBody = () => {}) {
  let body = "";
  request.on("data", (chunk) => { body += chunk; });
  request.on("end", () => {
    onBody(body, request.headers.authorization);
    response.writeHead(status, { "content-type": "application/json" });
    response.end(JSON.stringify({ acks: [{ client_event_id: event.client_event_id, ok, applied, error: ok ? null : "CONFLICT_ASSIGNMENT_CHANGED" }] }));
  });
}

test("drops one committed ACK, then forwards identical replay with one fake upstream accrual", async (t) => {
  const bodies = [];
  const tokens = [];
  let accruals = 0;
  const seen = new Set();
  const { send, events } = await harness(t, (request, response) => {
    assert.equal(request.headers["accept-encoding"], "identity");
    const first = !seen.has(event.client_event_id);
    respond(request, response, { applied: first }, (body, token) => {
      bodies.push(body); tokens.push(token);
      if (first) { seen.add(event.client_event_id); accruals++; }
    });
  });
  await assert.rejects(send(), /fetch failed/);
  assert.equal(accruals, 1);
  for (let n = 0; n < 2; n++) {
    const response = await send();
    assert.equal(response.status, 200);
    assert.equal((await response.json()).acks[0].applied, false);
  }
  assert.equal(accruals, 1);
  assert.deepEqual(bodies, Array(3).fill(JSON.stringify({ events: [event] })));
  assert.deepEqual(tokens, Array(3).fill(auth()));
  assert.deepEqual(events, [
    { type: "ack_dropped", client_event_id: event.client_event_id },
    ...Array(2).fill({ type: "ack_forwarded", client_event_id: event.client_event_id, applied: false }),
  ]);
});

for (const mismatch of ["company", "user", "project", "door", "status", "type", "batch", "token", "path"]) {
  test(`does not inject outside exact scope: ${mismatch}`, async (t) => {
    const { send, events } = await harness(t, (req, res) => respond(req, res));
    const changed = structuredClone(event);
    let token = auth();
    let path = "/api/v1/installer/sync";
    if (mismatch === "company") token = auth({ company_id: "another-company", sub: scope.userId });
    if (mismatch === "user") token = auth({ company_id: scope.companyId, sub: "another-user" });
    if (mismatch === "project") changed.project_id = "another-project";
    if (mismatch === "door") changed.payload.door_id = "another-door";
    if (mismatch === "status") changed.payload.status = "NOT_INSTALLED";
    if (mismatch === "type") changed.type = "ISSUE_CREATE";
    if (mismatch === "token") token = "Bearer invalid";
    if (mismatch === "path") path = "/api/v1/auth/login";
    const response = await send(mismatch === "batch" ? [changed, event] : [changed], token, path);
    assert.equal(response.status, 200);
    await response.text();
    assert.deepEqual(events, []);
  });
}

for (const result of [{ status: 403, ok: false, applied: false }, { status: 200, ok: false, applied: false }, { status: 200, ok: true, applied: false }]) {
  test(`passes through non-applied ACK ${JSON.stringify(result)}`, async (t) => {
    const { send, events } = await harness(t, (req, res) => respond(req, res, result));
    const response = await send();
    assert.equal(response.status, result.status);
    assert.equal((await response.json()).acks[0].applied, false);
    assert.deepEqual(events, []);
  });
}

test("requires an exact fault scope", () => {
  assert.throws(() => createSyncAckRelay({ upstreamPort: 8001, scope: {} }), /exact company/);
});
