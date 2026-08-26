#!/usr/bin/env python3
"""Integration tests for the LanguageTool bridge (standard library only)."""

import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "bin" / "languagetool-bridge"
FAILURES = []


def check(name, condition, detail=""):
    if condition:
        print("  ok  ", name)
    else:
        print("  FAIL", name, detail)
        FAILURES.append(name)


class FakeLanguageTool:
    def __init__(self):
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_GET(self):
                owner.requests.append(("GET", self.path, {}))
                if self.path == "/v2/languages":
                    self.send_json([
                        {"name": "French", "code": "fr"},
                        {"name": "English (US)", "code": "en-US"},
                    ])
                else:
                    self.send_error(404)

            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                fields = urllib.parse.parse_qs(
                    self.rfile.read(length).decode("utf-8"), keep_blank_values=True
                )
                owner.requests.append(("POST", self.path, fields))
                if fields.get("apiKey") == ["LEAK_ME"]:
                    self.send_json(
                        {"message": "Rejected LEAK_ME"}, status=401
                    )
                    return
                text = fields.get("text", [""])[0]
                offset = text.index("bon")
                # The bridge consumes Java/UTF-16 offsets. "😀" counts as 2.
                utf16_offset = len(text[:offset].encode("utf-16-le")) // 2
                self.send_json({
                    "language": {"detectedLanguage": {"code": "fr"}},
                    "matches": [
                        {
                            "message": "Accord",
                            "offset": utf16_offset,
                            "length": 3,
                            "replacements": [{"value": "bonne"}],
                            "rule": {"id": "TEST"},
                            "context": {"text": text},
                        },
                        {
                            "message": "Chevauchement ignoré pour le rendu",
                            "offset": utf16_offset + 1,
                            "length": 2,
                            "replacements": [{"value": "XX"}],
                            "rule": {"id": "OVERLAP"},
                        },
                    ],
                })

            def send_json(self, payload, status=200):
                body = json.dumps(payload).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        self.requests = []
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    @property
    def url(self):
        return "http://127.0.0.1:%d" % self.server.server_port

    def stop(self):
        self.server.shutdown()
        self.server.server_close()


class BridgeProcess:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory()
        env = os.environ.copy()
        env["XDG_STATE_HOME"] = self.temp.name
        self.process = subprocess.Popen(
            [sys.executable, str(BRIDGE)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        self.events = []
        self.lock = threading.Lock()
        threading.Thread(target=self._reader, daemon=True).start()

    def _reader(self):
        for line in self.process.stdout:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            with self.lock:
                self.events.append(event)

    def send(self, payload):
        command = dict(payload)
        command.setdefault("protocolVersion", 1)
        self.process.stdin.write(json.dumps(command) + "\n")
        self.process.stdin.flush()

    def wait_for(self, predicate, timeout=5, after=0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            with self.lock:
                events = list(self.events)
            for event in events[after:]:
                if predicate(event):
                    return event
            time.sleep(0.02)
        return None

    def snapshot(self):
        with self.lock:
            return list(self.events)

    def stop(self):
        if self.process.poll() is None:
            self.send({"op": "shutdown"})
            self.process.wait(timeout=3)
        self.temp.cleanup()


def test_languages_and_public_check():
    print("public: languages, correction and history")
    server = FakeLanguageTool()
    bridge = BridgeProcess()
    try:
        bridge.send({"op": "languages", "endpoint": server.url + "/v2"})
        languages = bridge.wait_for(lambda event: event.get("ev") == "languages")
        check("loads supported languages",
              languages and [item["code"] for item in languages["languages"]]
              == ["en-US", "fr"], languages)

        text = "😀 Ceci est bon."
        bridge.send({
            "op": "check", "requestId": "one", "endpoint": server.url,
            "mode": "public", "language": "auto", "text": text,
        })
        result_event = bridge.wait_for(
            lambda event: event.get("ev") == "check_result"
            and event.get("requestId") == "one"
        )
        result = result_event.get("result") if result_event else {}
        check("applies UTF-16 offsets correctly",
              result.get("corrected") == "😀 Ceci est bonne.", result)
        check("keeps all explanations",
              result.get("issueCount") == 2, result.get("issues"))
        check("does not apply overlapping replacements",
              "XX" not in result.get("corrected", ""), result.get("corrected"))
        request = [item for item in server.requests if item[0] == "POST"][0]
        check("uses /v2/check", request[1] == "/v2/check", request)
        check("public call has no credentials",
              "apiKey" not in request[2] and "username" not in request[2], request)

        history = bridge.wait_for(
            lambda event: event.get("ev") == "history"
            and len(event.get("entries", [])) == 1
        )
        check("stores successful checks", history is not None, bridge.snapshot())
        path = Path(bridge.temp.name) / "omarchy" / "languagetool" / "history.json"
        check("history file is private",
              path.exists() and (path.stat().st_mode & 0o777) == 0o600,
              oct(path.stat().st_mode & 0o777) if path.exists() else "missing")

        entry_id = result.get("id")
        marker = len(bridge.snapshot())
        bridge.send({"op": "history_delete", "id": entry_id})
        deleted = bridge.wait_for(
            lambda event: event.get("ev") == "history"
            and event.get("entries") == [], after=marker
        )
        check("deletes one history entry", deleted is not None)
    finally:
        bridge.stop()
        server.stop()


def test_premium_and_selfhosted():
    print("profiles: Premium credentials and self-hosted URL")
    server = FakeLanguageTool()
    bridge = BridgeProcess()
    try:
        bridge.send({
            "op": "check", "requestId": "premium", "endpoint": server.url + "/v2/",
            "mode": "premium", "username": "me@example.com", "apiKey": "secret",
            "language": "fr", "text": "😀 Ceci est bon.",
        })
        premium = bridge.wait_for(
            lambda event: event.get("ev") == "check_result"
            and event.get("requestId") == "premium"
        )
        check("premium check succeeds", premium is not None, bridge.snapshot())
        request = [item for item in server.requests if item[0] == "POST"][0]
        check("sends Premium credentials in POST body",
              request[2].get("username") == ["me@example.com"]
              and request[2].get("apiKey") == ["secret"], request)

        marker = len(bridge.snapshot())
        bridge.send({
            "op": "check", "requestId": "self", "endpoint": server.url,
            "mode": "selfhosted", "language": "auto",
            "text": "😀 Ceci est bon.",
        })
        selfhosted = bridge.wait_for(
            lambda event: event.get("ev") == "check_result"
            and event.get("requestId") == "self", after=marker
        )
        check("self-hosted check succeeds", selfhosted is not None)

        marker = len(bridge.snapshot())
        bridge.send({"op": "history_clear"})
        cleared = bridge.wait_for(
            lambda event: event.get("ev") == "history"
            and event.get("entries") == [], after=marker
        )
        check("clears all history", cleared is not None)
    finally:
        bridge.stop()
        server.stop()


def test_errors_redact_secrets():
    print("security: invalid endpoint and secret redaction")
    server = FakeLanguageTool()
    bridge = BridgeProcess()
    try:
        bridge.send({
            "op": "check", "requestId": "bad-url", "endpoint": "ftp://example.com",
            "mode": "selfhosted", "language": "auto", "text": "test",
        })
        invalid = bridge.wait_for(
            lambda event: event.get("ev") == "error"
            and event.get("requestId") == "bad-url"
        )
        check("rejects unsupported URL schemes",
              invalid and "HTTP" in invalid.get("message", ""), invalid)

        bridge.send({
            "op": "check", "requestId": "secret", "endpoint": server.url,
            "mode": "premium", "username": "me", "apiKey": "LEAK_ME",
            "language": "auto", "text": "test",
        })
        rejected = bridge.wait_for(
            lambda event: event.get("ev") == "error"
            and event.get("requestId") == "secret"
        )
        check("redacts API keys from errors",
              rejected and "LEAK_ME" not in json.dumps(rejected)
              and "[masqué]" in rejected.get("message", ""), rejected)
    finally:
        bridge.stop()
        server.stop()


def main():
    test_languages_and_public_check()
    print()
    test_premium_and_selfhosted()
    print()
    test_errors_redact_secrets()
    print()
    if FAILURES:
        print("FAILED:", ", ".join(FAILURES))
        return 1
    print("all tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
