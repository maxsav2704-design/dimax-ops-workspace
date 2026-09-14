"""Disposable HTTP fixture. Never connects to a DIMAX database or sends messages."""

import json
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock


counts = {}
lock = Lock()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def reply(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/ready":
            self.reply(200, {"fixture": True})
        elif self.path == "/counts":
            with lock:
                body = dict(counts)
            self.reply(200, body)
        else:
            self.reply(404, {"error": {"code": "NOT_FOUND"}})

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        with lock:
            counts[self.path] = counts.get(self.path, 0) + 1
            count = counts[self.path]
        if self.path.startswith("/lost-response/"):
            # Simulate an accepted write whose response never reaches the proxy.
            self.close_connection = True
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
        elif self.path == "/validation":
            self.reply(422, {"error": {"code": "VALIDATION_ERROR"}})
        else:
            self.reply(200, {"accepted": count})


ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
