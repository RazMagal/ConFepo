#!/usr/bin/env python3
"""confepo-lan-server regression suite.

Every hostile-input case here produced a traceback, a hang, or unbounded
buffering at some point (2026-08 audit); the /reply cases pin down the Phase-2
containment rules: the client names a session, never a pane; malformed input
gets a status code, never an exception; oversize input is rejected, never
truncated into the TUI.
"""
import http.client
import json
import os
import socket
import stat
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRV = os.path.join(REPO, "stow/lan/.local/lib/confepo/confepo-lan-server")
PORT = int(os.environ.get("CONFEPO_TEST_PORT", "18797"))
TOK = "testtoken123"

fails = []


def ok(cond, label, extra=""):
    print(f"   {'ok' if cond else 'FAIL'}: {label}" + (f" ({extra})" if extra and not cond else ""))
    if not cond:
        fails.append(label)


def post(path, body=b"", headers=None, timeout=5):
    c = http.client.HTTPConnection("127.0.0.1", PORT, timeout=timeout)
    c.putrequest("POST", path)
    for k, v in (headers or {}).items():
        c.putheader(k, v)
    c.endheaders()
    if body:
        c.send(body)
    r = c.getresponse()
    data = r.read()
    c.close()
    return r.status, data


def post_json(path, obj):
    raw = json.dumps(obj).encode()
    return post(path, raw, {"Content-Length": str(len(raw)),
                            "Content-Type": "application/json"})


tmp = tempfile.mkdtemp(prefix="confepo-lan-test.")
att = os.path.join(tmp, "attention")
os.makedirs(att)

# inject stub: records pane + stdin, exit code via CONFEPO_STUB_RC file
inject_log = os.path.join(tmp, "inject.log")
inject = os.path.join(tmp, "inject")
with open(inject, "w") as fh:
    fh.write("#!/usr/bin/env bash\n"
             f'printf "pane=%s text=%s\\n" "$1" "$(cat)" >> {inject_log}\n'
             f'rc_file={tmp}/rc; [ -f "$rc_file" ] && exit "$(cat "$rc_file")"; exit 0\n')
os.chmod(inject, os.stat(inject).st_mode | stat.S_IEXEC)

env = dict(os.environ,
           CONFEPO_LAN_CONF="/nonexistent",
           CONFEPO_LAN_PORT=str(PORT), CONFEPO_LAN_BIND="127.0.0.1",
           CONFEPO_LAN_TOKEN=TOK,
           CONFEPO_ATTENTION_DIR=att, CONFEPO_INJECT_BIN=inject,
           PYTHONPYCACHEPREFIX=tempfile.mkdtemp())
proc = subprocess.Popen([SRV], env=env, stderr=subprocess.PIPE)
time.sleep(0.8)

try:
    # ---- hostile-input regressions (each was a real failure once) ----------
    s, _ = post_json(f"/notify?t={TOK}", {"title": "hi", "body": "there"})
    ok(s == 204, "valid notify -> 204", str(s))
    s, _ = post(f"/notify?t={TOK}", b"", {"Content-Length": "abc"})
    ok(s == 400, "Content-Length: abc -> 400 (was ValueError)", str(s))
    s, _ = post(f"/notify?t={TOK}", b"", {"Content-Length": "-1"})
    ok(s == 400, "negative Content-Length -> 400 (was read-to-EOF hang)", str(s))
    s, _ = post(f"/notify?t={TOK}", b"", {"Content-Length": "8000000000"})
    ok(s == 413, "huge Content-Length -> 413 (was unbounded buffer)", str(s))
    big = b'{"body":"' + b"A" * 20000 + b'"}'
    s, _ = post(f"/notify?t={TOK}", big, {"Content-Length": str(len(big))})
    ok(s == 413, "20KB body -> 413", str(s))
    s, _ = post(f"/notify?t={TOK}", b"[1,2]", {"Content-Length": "5"})
    ok(s == 204, "JSON list body -> 204 (was AttributeError)", str(s))
    s, _ = post("/notify?t=wrong", b"", {"Content-Length": "abc"})
    ok(s == 403, "auth checked before body parsing", str(s))

    # ---- sid rides the SSE broadcast, invalid sid is dropped ---------------
    sse = socket.create_connection(("127.0.0.1", PORT), timeout=5)
    sse.sendall(f"GET /events?t={TOK} HTTP/1.1\r\nHost: x\r\n\r\n".encode())
    time.sleep(0.3)
    sse.recv(65536)  # headers + greeting
    post_json(f"/notify?t={TOK}", {"title": "T", "sid": "abc-123"})
    post_json(f"/notify?t={TOK}", {"title": "T", "sid": "../../etc/passwd"})
    time.sleep(0.3)
    stream = sse.recv(65536).decode()
    sse.close()
    ok('"sid": "abc-123"' in stream.replace(": ", ": ") or '"sid":"abc-123"' in stream.replace(" ", ""),
       "valid sid reaches the SSE stream", stream[:200])
    ok("passwd" not in stream, "path-shaped sid is dropped, never broadcast", stream[:200])

    # ---- /reply containment ------------------------------------------------
    with open(os.path.join(att, "goodsid"), "w") as fh:
        fh.write("pane=%7\ncwd=/somewhere\n")
    with open(os.path.join(att, "notmux"), "w") as fh:
        fh.write("pane=\ncwd=/somewhere\n")

    s, _ = post_json("/reply?t=wrong", {"sid": "goodsid", "text": "1"})
    ok(s == 403, "/reply requires auth", str(s))
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "../../x", "text": "1"})
    ok(s == 400, "path-shaped sid -> 400, filesystem never touched", str(s))
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "ghost", "text": "1"})
    ok(s == 404, "unknown sid -> 404", str(s))
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "notmux", "text": "1"})
    ok(s == 409, "session without a tmux pane -> 409", str(s))
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "goodsid", "text": "  "})
    ok(s == 400, "blank reply -> 400", str(s))
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "goodsid", "text": "x" * 501})
    ok(s == 413, "oversize reply -> 413, never truncated into the TUI", str(s))

    s, _ = post_json(f"/reply?t={TOK}", {"sid": "goodsid", "text": "2"})
    logged = open(inject_log).read() if os.path.exists(inject_log) else ""
    ok(s == 204 and "pane=%7 text=2" in logged,
       "valid reply -> 204, inject got the RECORDED pane + text", f"{s} {logged!r}")

    # client-supplied pane must be ignored even if present in the body
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "goodsid", "pane": "%99", "text": "3"})
    logged = open(inject_log).read()
    ok(s == 204 and "pane=%99" not in logged,
       "client-supplied pane is ignored — flag file wins", logged)

    with open(os.path.join(tmp, "rc"), "w") as fh:
        fh.write("5")
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "goodsid", "text": "4"})
    ok(s == 502, "inject failure -> 502", str(s))
    os.unlink(os.path.join(tmp, "rc"))

    # tampered flag file: pane that isn't %N must be refused
    with open(os.path.join(att, "weird"), "w") as fh:
        fh.write("pane=; rm -rf /\n")
    s, _ = post_json(f"/reply?t={TOK}", {"sid": "weird", "text": "1"})
    ok(s == 409, "non-%N pane in flag file -> 409, never exec'd", str(s))

finally:
    proc.terminate()
    err = proc.stderr.read().decode()

ok("Traceback" not in err, "no tracebacks in server stderr", err[-300:])
sys.exit(1 if fails else 0)
