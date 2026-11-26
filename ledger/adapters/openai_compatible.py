#!/usr/bin/env python3
"""Worked adapter: log one chat call to any OpenAI-compatible local server.

UNVERIFIED FOR LM STUDIO. LM Studio's docs page for its OpenAI-compatible API
(lmstudio.ai/docs/app/api/endpoints/openai) lists /v1/chat/completions and uses
port 1234 in its examples, but does not show a `usage` object. This script is
written against the generic OpenAI chat-completions response, where
`usage.prompt_tokens` and `usage.completion_tokens` are standard. If your server
leaves `usage` out, the line is sent WITHOUT token numbers (never zeros, never guesses).

Usage:  python3 openai_compatible.py "your prompt"
Env:    LOCAL_BASE_URL (default http://localhost:1234/v1), LOCAL_MODEL (required),
        LEDGER_TOKEN (not set = quietly does nothing about the ledger)
"""
import json, os, subprocess, sys, time, urllib.request
from datetime import datetime, timezone

base = os.environ.get("LOCAL_BASE_URL", "http://localhost:1234/v1")
model = os.environ["LOCAL_MODEL"]
prompt = " ".join(sys.argv[1:]) or sys.stdin.read()

started = datetime.now(timezone.utc)
t0 = time.time()
req = urllib.request.Request(base + "/chat/completions", method="POST",
                             headers={"Content-Type": "application/json"},
                             data=json.dumps({"model": model, "messages": [{"role": "user", "content": prompt}]}).encode())
with urllib.request.urlopen(req, timeout=600) as r:
    resp = json.load(r)
seconds = time.time() - t0
print(resp["choices"][0]["message"]["content"])

# The line: only what the tool really reported.
line = {"source": "local-model", "model": model,
        "started_at": started.isoformat(), "ended_at": datetime.now(timezone.utc).isoformat(),
        "ai_minutes": round(seconds / 60, 2)}           # measured by this script's own clock
usage = resp.get("usage") or {}
if isinstance(usage.get("prompt_tokens"), int):
    line["tokens_input"] = usage["prompt_tokens"]
if isinstance(usage.get("completion_tokens"), int):
    line["tokens_output"] = usage["completion_tokens"]
# No cost_usd: a local model has no API price, so none is invented.

ledger = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "plugin", "scripts", "ledger.py")
subprocess.run([sys.executable, ledger, "emit"], input=json.dumps(line), text=True)
