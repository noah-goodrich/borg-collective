#!/usr/bin/env python3
"""Local-only stand-in for the Anthropic messages API, for tests/smoke/resume_real.sh.

Binds 127.0.0.1 on an ephemeral port and writes the port number to <portfile>. It can NEVER produce a successful
completion: every POST gets an error, chosen by the one-word mode file (re-read per request):
  429        HTTP 429 rate_limit_error (what a usage limit looks like to the client)
  404model   HTTP 404 not_found_error (what an invalid model name looks like)
  anything else / missing   HTTP 400 invalid_request_error
Every error carries x-should-retry: false so the client gives up at once instead of backing off for minutes.
It logs one line per request (time, method, path, status) to <logfile> and never headers or bodies, so the
credential the client sends stays out of every file.

Usage: resume_stub_api.py <portfile> <logfile> <modefile>      (run with python3 -I)
"""

import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORTFILE, LOGFILE, MODEFILE = sys.argv[1:4]


def mode():
    try:
        with open(MODEFILE) as f:
            return f.read().strip()
    except OSError:
        return ""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _reply(self, code, kind, message):
        data = json.dumps({"type": "error", "error": {"type": kind, "message": message}}).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.send_header("x-should-retry", "false")
        if code == 429:
            self.send_header("retry-after", "1")
        self.end_headers()
        self.wfile.write(data)
        with open(LOGFILE, "a") as f:
            f.write("%d %s %s %d\n" % (time.time(), self.command, self.path, code))

    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length") or 0))
        m = mode()
        if m == "429":
            self._reply(429, "rate_limit_error", "smoke stub: rate limit")
        elif m == "404model":
            self._reply(404, "not_found_error", "model: smoke stub: no such model")
        else:
            self._reply(400, "invalid_request_error", "smoke stub: unsupported")

    def do_GET(self):
        self._reply(404, "not_found_error", "smoke stub")

    do_HEAD = do_GET
    do_PUT = do_POST
    do_DELETE = do_GET


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(PORTFILE + ".tmp", "w") as f:
        f.write(str(server.server_address[1]))
    import os

    os.replace(PORTFILE + ".tmp", PORTFILE)
    server.serve_forever()
