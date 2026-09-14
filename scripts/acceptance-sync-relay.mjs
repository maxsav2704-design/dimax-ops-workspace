import http from "node:http";
import { parseArgs } from "node:util";
import { pathToFileURL } from "node:url";

const MAX_SYNC_BYTES = 2 * 1024 * 1024;
const HOP_HEADERS = new Set([
  "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
  "te", "trailer", "transfer-encoding", "upgrade",
]);

function forwardedHeaders(headers) {
  const excluded = new Set([
    ...HOP_HEADERS, ...String(headers.connection ?? "").toLowerCase().split(",").map((part) => part.trim()),
  ]);
  return Object.fromEntries(Object.entries(headers).filter(([key]) => !excluded.has(key)));
}

function scopedEvent(request, body, scope) {
  try {
    // This selects a fault, not an identity grant. The backend still validates the JWT.
    const token = String(request.headers.authorization ?? "").replace(/^Bearer /i, "");
    const claims = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());
    const { events } = JSON.parse(body.toString());
    if (claims.company_id !== scope.companyId || claims.sub !== scope.userId || events?.length !== 1) return null;
    const event = events[0];
    return event.type === "DOOR_SET_STATUS" && event.project_id === scope.projectId &&
      event.payload?.door_id === scope.doorId && event.payload?.status === "INSTALLED" &&
      typeof event.client_event_id === "string" ? event : null;
  } catch {
    return null;
  }
}

export function createSyncAckRelay({ upstreamPort, scope, onEvent = () => {} }) {
  if (!Number.isInteger(upstreamPort) || upstreamPort < 1 || upstreamPort > 65535) throw new Error("Invalid upstream port");
  if (![scope?.companyId, scope?.userId, scope?.projectId, scope?.doorId].every((id) => typeof id === "string" && id.length > 0)) {
    throw new Error("An exact company, user, project and door scope is required");
  }
  let droppedEventId = null;
  const server = http.createServer((request, response) => {
    const forward = (body, event) => {
      const headers = forwardedHeaders(request.headers);
      headers.host = `127.0.0.1:${upstreamPort}`;
      if (event) headers["accept-encoding"] = "identity";
      if (body) headers["content-length"] = String(body.length);
      const upstream = http.request({
        hostname: "127.0.0.1", port: upstreamPort, method: request.method,
        path: request.url, headers,
      }, (incoming) => {
        const sendHeaders = () => response.writeHead(incoming.statusCode ?? 502, forwardedHeaders(incoming.headers));
        incoming.on("error", () => response.destroy());
        if (!event || (droppedEventId && droppedEventId !== event.client_event_id)) {
          sendHeaders();
          incoming.pipe(response);
          return;
        }
        const chunks = [];
        let size = 0;
        incoming.on("data", (chunk) => {
          size += chunk.length;
          if (size > 8 * 1024 * 1024) {
            incoming.destroy();
            response.destroy();
          } else chunks.push(chunk);
        });
        incoming.on("end", () => {
          if (response.destroyed) return;
          const reply = Buffer.concat(chunks);
          let ack;
          try {
            ack = JSON.parse(reply.toString()).acks?.find((item) => item.client_event_id === event.client_event_id);
          } catch { /* Non-JSON upstream errors must pass through unchanged. */ }
          const accepted = incoming.statusCode >= 200 && incoming.statusCode < 300 && ack?.ok === true;
          if (!droppedEventId && accepted && ack.applied === true) {
            droppedEventId = event.client_event_id;
            onEvent({ type: "ack_dropped", client_event_id: droppedEventId });
            response.destroy();
            return;
          }
          if (accepted && droppedEventId === event.client_event_id) {
            onEvent({ type: "ack_forwarded", client_event_id: droppedEventId, applied: ack.applied });
          }
          sendHeaders();
          response.end(reply);
        });
      });
      upstream.setTimeout(35000, () => upstream.destroy(new Error("Upstream timeout")));
      upstream.on("error", () => {
        if (response.destroyed) return;
        if (!response.headersSent) response.writeHead(502, { "content-type": "application/json" });
        response.end('{"detail":"Acceptance relay upstream unavailable"}');
      });
      response.on("close", () => { if (!response.writableFinished) upstream.destroy(); });
      if (body) upstream.end(body);
      else request.pipe(upstream);
    };
    if (!request.url?.startsWith("/") || request.url.startsWith("//")) {
      response.writeHead(400).end();
      return;
    }
    if (request.method !== "POST" || request.url.split("?")[0] !== "/api/v1/installer/sync") {
      forward(null, null);
      return;
    }
    const chunks = [];
    let size = 0;
    request.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_SYNC_BYTES) {
        response.writeHead(413).end();
        request.destroy();
      } else chunks.push(chunk);
    });
    request.on("end", () => {
      if (size > MAX_SYNC_BYTES) return;
      const body = Buffer.concat(chunks);
      forward(body, scopedEvent(request, body, scope));
    });
    request.on("error", () => response.destroy());
  });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { values } = parseArgs({ options: { "door-id": { type: "string" }, port: { type: "string", default: "18001" } } });
  const port = Number(values.port);
  if (!Number.isInteger(port) || port < 1024 || port > 65535 || [8000, 8001, 8081].includes(port)) throw new Error("Invalid relay port");
  const relay = createSyncAckRelay({
    upstreamPort: 8001,
    scope: {
      companyId: "d1861479-addc-5655-b5c4-f86456bb04d8",
      userId: "028de8c2-35de-50bf-9f7d-fecb35b17180",
      projectId: "6423143b-4122-4685-8f8f-20fe848bc8b7",
      doorId: values["door-id"],
    },
    onEvent: (event) => process.stdout.write(`${JSON.stringify(event)}\n`),
  });
  relay.on("error", (error) => { process.stderr.write(`${error.code ?? "Relay error"}\n`); process.exitCode = 1; });
  relay.listen(port, "127.0.0.1", () => process.stdout.write(`Acceptance relay listening on 127.0.0.1:${port}\n`));
  const stop = () => { relay.close(); relay.closeAllConnections(); };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
}
