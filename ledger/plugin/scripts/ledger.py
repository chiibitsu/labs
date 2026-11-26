#!/usr/bin/env python3
"""Time Dividend ledger client for Claude Code.

  ledger.py hook          Stop / SessionStart hook. Reads the hook JSON on stdin,
                          measures the session from its transcript, and upserts
                          timing (AI minutes, your minutes) and the cost and
                          token totals Claude Code reports into the ledger.
                          On SessionStart it also prints the keep list and the
                          logging command as session context.
  ledger.py emit          Adapter intake for any other tool: reads one line in the
                          common line format (ledger/FORMAT.md) on stdin and records it.
                          Never invents numbers; says so if it cannot reach the ledger.
  ledger.py flush         Retries lines that could not be sent earlier.
  ledger.py entry         Reads an entry JSON on stdin (title, human estimate,
                          actions...) and records it against the current session.

Writes go to the Supabase RPC public.ledger_ingest, gated by your intake token
(LEDGER_TOKEN, or the plugin's ledger_token option). Never blocks Claude: every
failure exits 0 and stays quiet, except `entry`, which reports the outcome.
"""
import hashlib, json, os, sys, time, urllib.request
from datetime import datetime, timezone

URL = os.environ.get("LEDGER_URL", "https://wguhmblrcfcvbheusizt.supabase.co")
# Publishable key: safe to ship. Row-level security keeps every ledger table private.
KEY = os.environ.get("LEDGER_KEY", "sb_publishable_Y_jI74qFxdAlZb4elby75A_7QlUky9a")
TOKEN = os.environ.get("LEDGER_TOKEN") or os.environ.get("CLAUDE_PLUGIN_OPTION_LEDGER_TOKEN") or ""

IDLE_CAP = 5 * 60      # a gap longer than this before a prompt counts as away, not engaged
AI_GAP_CAP = 10 * 60   # a gap longer than this between AI events is not AI work
FIRST_READ = 2 * 60    # time credited for the first prompt and the final read


def state_dir():
    d = os.environ.get("CLAUDE_PLUGIN_DATA") or os.path.join(os.path.expanduser("~"), ".claude", "time-dividend")
    os.makedirs(d, exist_ok=True)
    return d


def state_file(cwd):
    return os.path.join(state_dir(), "session-" + hashlib.sha1((cwd or "").encode()).hexdigest()[:16] + ".json")


def rpc(fn, payload, timeout=8):
    req = urllib.request.Request(
        f"{URL}/rest/v1/rpc/{fn}", data=json.dumps(payload).encode(), method="POST",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode() or "null"
    return json.loads(body)


def ts(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def is_human_prompt(d):
    if d.get("type") != "user" or d.get("isMeta") or d.get("isSidechain"):
        return False
    origin = d.get("origin") or {}
    if isinstance(origin, dict) and origin.get("kind"):
        return origin.get("kind") == "human"
    if d.get("turnOrigin"):
        return d.get("turnOrigin") == "human"
    content = (d.get("message") or {}).get("content")
    if isinstance(content, str):
        return not content.lstrip().startswith("<")
    if isinstance(content, list):
        types = {b.get("type") for b in content if isinstance(b, dict)}
        return "text" in types and "tool_result" not in types
    return False


def usage_totals(snap):
    """Flatten one cost-state snapshot into cost + token totals."""
    mu = snap.get("modelUsage") or {}
    tot = {"cost_usd": float(snap.get("totalCostUSD") or 0), "tokens_input": 0, "tokens_cache_read": 0, "tokens_output": 0}
    for u in mu.values():
        tot["tokens_input"] += int(u.get("inputTokens") or 0) + int(u.get("cacheCreationInputTokens") or 0)
        tot["tokens_cache_read"] += int(u.get("cacheReadInputTokens") or 0)
        tot["tokens_output"] += int(u.get("outputTokens") or 0)
    return tot, mu


# List prices in USD per million tokens, from Anthropic's published API prices
# (cached 2026-11-03). A model not listed here is NEVER priced: its tokens are
# recorded and its cost is left out. 5m cache write = 1.25x input, 1h = 2x input.
# "fast" speed costs more and is not priced here, so those messages are left unpriced.
PRICES = {
    "claude-fable-5-2": {"in": 8.00, "out": 40.00, "read": 0.20},
    "claude-opus-5-5": {"in": 4.00, "out": 20.00, "read": 0.20},
    "claude-sonnet-5-5": {"in": 2.00, "out": 10.00, "read": 0.10},
}


def price_message(model, u):
    """USD for one message's usage, or None if we cannot price it honestly."""
    p = PRICES.get(model)
    if not p or u.get("speed") not in (None, "standard"):
        return None
    cc = u.get("cache_creation") or {}
    w1h = int(cc.get("ephemeral_1h_input_tokens") or 0)
    w5m = int(cc.get("ephemeral_5m_input_tokens") or 0)
    if not cc:  # no TTL split reported: charge the dearer 1h rate rather than under-state
        w1h = int(u.get("cache_creation_input_tokens") or 0)
    per = lambda n, rate: n * rate / 1e6
    return (per(int(u.get("input_tokens") or 0), p["in"]) + per(int(u.get("output_tokens") or 0), p["out"])
            + per(int(u.get("cache_read_input_tokens") or 0), p["read"])
            + per(w5m, p["in"] * 1.25) + per(w1h, p["in"] * 2))


def transcript_files(path):
    """The main transcript plus any subagent transcripts stored beside it."""
    stem = os.path.splitext(path)[0]
    sub = os.path.join(stem, "subagents")
    extra = sorted(os.path.join(sub, n) for n in os.listdir(sub) if n.endswith(".jsonl")) if os.path.isdir(sub) else []
    return [path] + extra


def usage_from_messages(path):
    """Sum per-message usage across the transcript (and subagents), once per message id.
    Claude Code writes the same API message on several lines, so de-duplicate by id."""
    seen, models, cost, unpriced, any_priced = set(), {}, 0.0, False, False
    for fp in transcript_files(path):
        try:
            f = open(fp, encoding="utf-8")
        except Exception:
            continue
        with f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                m = d.get("message")
                if d.get("type") != "assistant" or not isinstance(m, dict) or not m.get("usage"):
                    continue
                mid, model, u = m.get("id"), m.get("model") or "unknown", m["usage"]
                if model.startswith("<") or (mid and mid in seen):
                    continue
                if mid:
                    seen.add(mid)
                row = models.setdefault(model, {"inputTokens": 0, "cacheCreationInputTokens": 0,
                                                "cacheReadInputTokens": 0, "outputTokens": 0, "priced": True})
                row["inputTokens"] += int(u.get("input_tokens") or 0)
                row["cacheCreationInputTokens"] += int(u.get("cache_creation_input_tokens") or 0)
                row["cacheReadInputTokens"] += int(u.get("cache_read_input_tokens") or 0)
                row["outputTokens"] += int(u.get("output_tokens") or 0)
                c = price_message(model, u)
                if c is None:
                    row["priced"] = False
                    unpriced = True
                else:
                    cost += c
                    any_priced = True
    if not models:
        return {}
    out = {"tokens_input": sum(r["inputTokens"] + r["cacheCreationInputTokens"] for r in models.values()),
           "tokens_cache_read": sum(r["cacheReadInputTokens"] for r in models.values()),
           "tokens_output": sum(r["outputTokens"] for r in models.values()),
           "model_usage": models}
    if any_priced:
        out["cost_usd"] = round(cost, 4)
        out["cost_basis"] = "partial" if unpriced else "estimate"
    return out


def project_name(cwd):
    """Project for a line, by rule (no agent judgment): $LEDGER_PROJECT if set, else the
    repo name from git's origin URL, else the folder name."""
    if os.environ.get("LEDGER_PROJECT"):
        return os.environ["LEDGER_PROJECT"]
    try:
        import subprocess
        url = subprocess.run(["git", "-C", cwd, "config", "--get", "remote.origin.url"],
                             capture_output=True, text=True, timeout=3).stdout.strip()
        name = url.rstrip("/").rsplit("/", 1)[-1].rsplit(":", 1)[-1]
        if name.endswith(".git"):
            name = name[:-4]
        if name:
            return name
    except Exception:
        pass
    return os.path.basename(cwd.rstrip("/")) or None


def spool_path():
    return os.path.join(state_dir(), "unsent.json")


def spool(entry, err):
    """Keep the latest unsent line per session so it can be retried, and remember why."""
    try:
        try:
            with open(spool_path()) as f:
                box = json.load(f)
        except Exception:
            box = {}
        box[f"{entry.get('source')}:{entry.get('external_id') or id(entry)}"] = {"entry": entry, "error": str(err)[:200], "at": time.time()}
        with open(spool_path(), "w") as f:
            json.dump(box, f)
    except Exception:
        pass


def unspool(entry):
    """A newer send succeeded: drop any older unsent snapshot of the same session."""
    try:
        with open(spool_path()) as f:
            box = json.load(f)
        if box.pop(f"{entry.get('source')}:{entry.get('external_id')}", None) is not None:
            if box:
                with open(spool_path(), "w") as f:
                    json.dump(box, f)
            else:
                os.remove(spool_path())
    except Exception:
        pass


def flush():
    """Retry spooled lines. Returns (sent, still_unsent, last_error)."""
    try:
        with open(spool_path()) as f:
            box = json.load(f)
    except Exception:
        return 0, 0, None
    sent, err = 0, None
    for k in list(box):
        try:
            rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": box[k]["entry"]}, timeout=5)
            del box[k]
            sent += 1
        except Exception as e:
            err = str(e)[:200]
            break
    try:
        if box:
            with open(spool_path(), "w") as f:
                json.dump(box, f)
        elif os.path.exists(spool_path()):
            os.remove(spool_path())
    except Exception:
        pass
    return sent, len(box), err


def measure(path):
    """Return timing and cost for a transcript: start, end, ai/you minutes, cost, tokens, first prompt."""
    ai_events, prompts, first_text = [], [], None
    # cost-state lines are running totals for the current process; if a resumed
    # session restarts them, bank the earlier run and keep adding.
    banked, last, models = None, None, {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") == "cost-state":
                cur, mu = usage_totals(d)
                if last and cur["cost_usd"] + 1e-9 < last["cost_usd"]:
                    banked = {k: (banked or {}).get(k, 0) + last[k] for k in last}
                last = cur
                for name, u in mu.items():
                    models[name] = {k: v for k, v in u.items() if isinstance(v, (int, float))}
                continue
            t = ts(d.get("timestamp") or "")
            if t is None or d.get("isSidechain"):
                continue
            if is_human_prompt(d):
                prompts.append(t)
                if first_text is None:
                    c = (d.get("message") or {}).get("content")
                    if isinstance(c, list):
                        c = " ".join(b.get("text", "") for b in c if isinstance(b, dict))
                    first_text = " ".join(str(c or "").split())[:90]
            elif d.get("type") in ("assistant", "user"):
                ai_events.append(t)
                if first_text is None and d.get("type") == "user" and not d.get("isMeta"):
                    c = (d.get("message") or {}).get("content")
                    if isinstance(c, str):
                        first_text = " ".join(c.split())[:90]
    unattended = not prompts
    if unattended:
        # Started by another session or a scheduler: no human prompt to time. Still log the
        # AI time and spend; "your minutes" stays unknown (left out), never guessed.
        if not ai_events:
            return None
    every = sorted(ai_events + prompts)
    ai = sum(min(b - a, AI_GAP_CAP) for a, b in zip(ai_events, ai_events[1:]) if b - a < AI_GAP_CAP)
    you = FIRST_READ
    for p in prompts[1:]:
        before = [e for e in ai_events if e < p]
        if before:
            you += min(p - before[-1], IDLE_CAP)
    if prompts and ai_events and ai_events[-1] > prompts[-1]:
        you += FIRST_READ
    iso = lambda x: datetime.fromtimestamp(x, timezone.utc).isoformat()
    out = {"started_at": iso(every[0]), "ended_at": iso(every[-1]),
           "ai_minutes": round(ai / 60, 1), "first_prompt": first_text or ""}
    if not unattended:
        out["you_minutes"] = round(you / 60, 1)
    if last:
        total = {k: last[k] + (banked or {}).get(k, 0) for k in last}
        out.update({"cost_usd": round(total["cost_usd"], 4), "tokens_input": total["tokens_input"],
                    "tokens_cache_read": total["tokens_cache_read"], "tokens_output": total["tokens_output"],
                    "model_usage": models, "cost_basis": "reported"})
    else:
        # No cost-state lines (cloud transcripts have none): count tokens from message usage.
        out.update(usage_from_messages(path))
    return out


def keep_context():
    try:
        rows = rpc("ledger_keep_for", {"p_token": TOKEN}, timeout=5) or []
    except Exception:
        return ""
    if not rows:
        return ""
    lines = "\n".join(f"- {r['label']}" + (f" ({r['why']})" if r.get("why") else "") for r in rows)
    return ("Keep list: these are Chii's to do. Do not do them; hand them back with a short nudge "
            "(what's ready, what's left for her):\n" + lines)


def hook():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    sid, cwd, path = data.get("session_id"), data.get("cwd") or os.getcwd(), data.get("transcript_path")
    event = data.get("hook_event_name", "")
    if not sid or not TOKEN:
        return
    try:
        with open(state_file(cwd), "w") as f:
            json.dump({"session_id": sid, "transcript_path": path, "at": time.time()}, f)
    except Exception:
        pass
    if event == "SessionStart":
        here = os.path.abspath(__file__)
        ctx = ("Time Dividend ledger is on for this session. When a piece of work is finished, log it with the "
               f"log-session skill; it records through: python3 \"{here}\" entry")
        sent, left, err = flush()
        if left:
            ctx += ("\n\nLEDGER WARNING: " + str(left) + " earlier session line(s) could not be sent to the ledger "
                    f"({err}). Tell Chii once, plainly. Do not make up numbers.")
        keep = keep_context()
        if keep:
            ctx += "\n\n" + keep
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
        return
    if not path or not os.path.exists(path):
        return
    m = measure(path)
    if not m:
        return
    entry = {"source": "claude-code", "external_id": sid, "project": project_name(cwd),
             "title_if_empty": m.pop("first_prompt") or None, **m}
    try:
        rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": entry})
        unspool(entry)
    except Exception as err:
        spool(entry, err)  # said out loud at the next session start; never blocks Claude


def entry():
    if not TOKEN:
        print("ledger: no LEDGER_TOKEN set; create one on the ledger page and add it to the environment.")
        return
    raw = sys.stdin.read()
    try:
        e = json.loads(raw)
    except Exception as err:
        print(f"ledger: entry is not valid JSON ({err})")
        return
    e.setdefault("source", "claude-code")
    cwd = os.getcwd()
    try:
        with open(state_file(cwd)) as f:
            st = json.load(f)
        e.setdefault("external_id", st.get("session_id"))
        if st.get("transcript_path") and os.path.exists(st["transcript_path"]):
            m = measure(st["transcript_path"]) or {}
            m.pop("first_prompt", None)
            for k, v in m.items():
                e.setdefault(k, v)
    except Exception:
        pass
    e.setdefault("project", project_name(cwd))
    try:
        sid = rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": e})
        unspool(e)
        saved = (e.get("human_minutes") or 0) - (e.get("you_minutes") or 0)
        cost = f" · cost ${e['cost_usd']:.2f}" if e.get("cost_usd") is not None else ""
        print(f"ledger: recorded session {sid} · you {e.get('you_minutes')} min · "
              f"human-equivalent {e.get('human_minutes')} min · saved ≈ {round(saved)} min{cost}")
    except Exception as err:
        spool(e, err)
        print(f"ledger: could not record ({err}). Kept locally to retry; nothing was invented.")


EMIT_NUMBERS = ("ai_minutes", "you_minutes", "tokens_input", "tokens_cache_read", "tokens_output", "cost_usd")


def emit():
    """Adapter intake: one line in the common format (ledger/FORMAT.md) on stdin."""
    if not TOKEN:
        return  # not wired here: stop quietly
    try:
        e = json.loads(sys.stdin.read())
        assert isinstance(e, dict)
    except Exception as err:
        print(f"ledger: line is not a JSON object ({err}); nothing sent.")
        return
    if not e.get("source"):
        print("ledger: line has no `source` (the tool name); nothing sent.")
        return
    for k in EMIT_NUMBERS:  # a missing number stays missing; a wrong one is refused
        if e.get(k) is not None and (not isinstance(e[k], (int, float)) or isinstance(e[k], bool) or e[k] < 0):
            print(f"ledger: `{k}` must be a number >= 0; nothing sent.")
            return
    if e.get("cost_usd") is not None and e.get("cost_basis") not in ("reported", "partial", "estimate", "manual"):
        print("ledger: `cost_usd` needs `cost_basis` (reported, partial, estimate or manual); nothing sent.")
        return
    model = e.pop("model", None)  # convenience: one model name, tokens as above
    if model and not e.get("model_usage"):
        e["model_usage"] = {model: {k: e[t] for k, t in (("inputTokens", "tokens_input"), ("cacheReadInputTokens", "tokens_cache_read"),
                                                         ("outputTokens", "tokens_output")) if e.get(t) is not None}}
    e.setdefault("started_at", datetime.now(timezone.utc).isoformat())
    e.setdefault("project", project_name(os.getcwd()))
    try:
        sid = rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": e})
        unspool(e)
        print(f"ledger: recorded {e['source']} line {sid}")
    except Exception as err:
        spool(e, err)
        print(f"ledger: could not reach the ledger ({err}). Kept locally; run `ledger.py flush` later. Nothing was invented.")


def flush_cmd():
    if not TOKEN:
        return
    sent, left, err = flush()
    print(f"ledger: sent {sent}, still waiting {left}" + (f" ({err})" if left else ""))


if __name__ == "__main__":
    {"hook": hook, "entry": entry, "emit": emit, "flush": flush_cmd}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: None)()
