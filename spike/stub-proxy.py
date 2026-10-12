#!/usr/bin/env python3
"""Local stub for the Anthropic messages API (spike slice S0b).

Binds 127.0.0.1 only. Never logs headers or bodies (credentials stay out of
the log); logs one line per request: time, method, path, status served.
Mode comes from the file named by STUB_MODE_FILE (re-read per request):
  ok | 429 | 429week | 529 | 500 | 401 | 400
  tool429:<Tool>[:<scriptPath>]  first streamed request offering <Tool> answers with a tool_use,
                  then the mode flips to 429 (subagent API error probe)
"""

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE_FILE = os.environ.get("STUB_MODE_FILE", "")
LOG = os.environ.get("STUB_LOG", "")


def mode():
    try:
        with open(MODE_FILE) as f:
            return f.read().strip() or "ok"
    except OSError:
        return "ok"


def err(kind, msg):
    return {"type": "error", "error": {"type": kind, "message": msg}}


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _send(self, code, body, extra=None):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def _sse(self, events):
        out = b""
        for name, data in events:
            out += ("event: %s\ndata: %s\n\n" % (name, json.dumps(data))).encode()
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("content-length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def _head(self):
        return (
            "message_start",
            {
                "type": "message_start",
                "message": {
                    "id": "msg_stub",
                    "type": "message",
                    "role": "assistant",
                    "model": "stub",
                    "content": [],
                    "stop_reason": None,
                    "stop_sequence": None,
                    "usage": {"input_tokens": 1, "output_tokens": 1},
                },
            },
        )

    def _sse_text(self, text):
        self._sse(
            [
                self._head(),
                (
                    "content_block_start",
                    {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}},
                ),
                (
                    "content_block_delta",
                    {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": text}},
                ),
                ("content_block_stop", {"type": "content_block_stop", "index": 0}),
                (
                    "message_delta",
                    {
                        "type": "message_delta",
                        "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                        "usage": {"output_tokens": 1},
                    },
                ),
                ("message_stop", {"type": "message_stop"}),
            ]
        )

    def _sse_tool(self, tool, arg=""):
        args = {"description": "spike probe", "prompt": "say ok", "subagent_type": "general-purpose"}
        if tool == "Workflow":
            args = {"scriptPath": arg}
        self._sse(
            [
                self._head(),
                (
                    "content_block_start",
                    {
                        "type": "content_block_start",
                        "index": 0,
                        "content_block": {"type": "tool_use", "id": "toolu_stub01", "name": tool, "input": {}},
                    },
                ),
                (
                    "content_block_delta",
                    {
                        "type": "content_block_delta",
                        "index": 0,
                        "delta": {"type": "input_json_delta", "partial_json": json.dumps(args)},
                    },
                ),
                ("content_block_stop", {"type": "content_block_stop", "index": 0}),
                (
                    "message_delta",
                    {
                        "type": "message_delta",
                        "delta": {"stop_reason": "tool_use", "stop_sequence": None},
                        "usage": {"output_tokens": 1},
                    },
                ),
                ("message_stop", {"type": "message_stop"}),
            ]
        )

    def _note(self, code):
        if LOG:
            with open(LOG, "a") as f:
                f.write("%d %s %s %s\n" % (time.time(), self.command, self.path, code))

    def do_POST(self):
        n = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(n)
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            body = {}
        m = mode()
        names = [t.get("name") for t in body.get("tools") or [] if isinstance(t, dict)]
        if m.startswith("tool429:") and body.get("stream") and "/messages" in self.path:
            tool, _, arg = m.split(":", 1)[1].partition(":")
            if tool in names:
                with open(MODE_FILE, "w") as f:
                    f.write("429")
                self._note("tool_use:" + tool)
                return self._sse_tool(tool, arg)
            m = "ok"
        reset = str(int(time.time()) + 3 * 3600)
        if m in ("429", "429week"):
            claim = "seven_day" if m == "429week" else "five_hour"
            hdr = {
                "anthropic-ratelimit-unified-status": "rejected",
                "anthropic-ratelimit-unified-reset": reset,
                "anthropic-ratelimit-unified-representative-claim": claim,
                "retry-after": "10800",
            }
            self._note(429)
            return self._send(429, err("rate_limit_error", "rate limit"), hdr)
        if m == "529":
            self._note(529)
            return self._send(529, err("overloaded_error", "Overloaded"))
        if m == "500":
            self._note(500)
            return self._send(500, err("api_error", "Internal server error"))
        if m == "401":
            self._note(401)
            return self._send(401, err("authentication_error", "invalid x-api-key"))
        if m == "400":
            self._note(400)
            return self._send(400, err("invalid_request_error", "invalid request"))
        self._note(200)
        if body.get("stream"):
            return self._sse_text("ok")
        return self._send(
            200,
            {
                "id": "msg_stub",
                "type": "message",
                "role": "assistant",
                "model": "stub",
                "content": [{"type": "text", "text": "ok"}],
                "stop_reason": "end_turn",
                "stop_sequence": None,
                "usage": {"input_tokens": 1, "output_tokens": 1},
            },
        )

    def do_GET(self):
        self._note(404)
        self._send(404, err("not_found_error", "stub"))

    do_HEAD = do_GET


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18099
    HTTPServer(("127.0.0.1", port), H).serve_forever()
