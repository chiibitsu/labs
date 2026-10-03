#!/usr/bin/env python3
"""Time Dividend ledger client for Claude Code.

  ledger.py hook          Stop / SessionStart hook. Reads the hook JSON on stdin,
                          measures the session from its transcript, and upserts
                          timing (AI minutes, your minutes) and the cost and
                          token totals Claude Code reports into the ledger.
                          On SessionStart it also prints the keep list and the
                          logging command as session context.
  ledger.py entry         Reads an entry JSON on stdin (title, human estimate,
                          actions...) and records it against the current session.
                          Works without the plugin: it then finds the session's
                          transcript itself (the newest one under ~/.claude/projects).
  ledger.py keep          Prints the keep list, for sessions without the hooks.

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
    if not prompts:
        return None
    every = sorted(ai_events + prompts)
    ai = sum(min(b - a, AI_GAP_CAP) for a, b in zip(ai_events, ai_events[1:]) if b - a < AI_GAP_CAP)
    you = FIRST_READ
    for p in prompts[1:]:
        before = [e for e in ai_events if e < p]
        if before:
            you += min(p - before[-1], IDLE_CAP)
    if ai_events and ai_events[-1] > prompts[-1]:
        you += FIRST_READ
    iso = lambda x: datetime.fromtimestamp(x, timezone.utc).isoformat()
    out = {"started_at": iso(every[0]), "ended_at": iso(every[-1]),
           "ai_minutes": round(ai / 60, 1), "you_minutes": round(you / 60, 1),
           "first_prompt": first_text or ""}
    if last:
        total = {k: last[k] + (banked or {}).get(k, 0) for k in last}
        out.update({"cost_usd": round(total["cost_usd"], 4), "tokens_input": total["tokens_input"],
                    "tokens_cache_read": total["tokens_cache_read"], "tokens_output": total["tokens_output"],
                    "model_usage": models, "cost_basis": "reported"})
    return out


def newest_transcript():
    """Without the plugin's hooks there is no state file. The running session's transcript
    is the most recently written one under ~/.claude/projects; its filename is the session id."""
    root = os.path.join(os.path.expanduser("~"), ".claude", "projects")
    best = None
    for dirpath, _, files in os.walk(root):
        for name in files:
            if name.endswith(".jsonl"):
                p = os.path.join(dirpath, name)
                t = os.path.getmtime(p)
                if not best or t > best[0]:
                    best = (t, p)
    if not best:
        return {}
    return {"session_id": os.path.basename(best[1])[:-6], "transcript_path": best[1]}


def keep():
    """Print the active keep list (tasks the AI hands back). For sessions without the hooks."""
    if not TOKEN:
        print("ledger: no LEDGER_TOKEN set.")
        return
    print(keep_context() or "Keep list: empty or unreachable.")


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
    entry = {"source": "claude-code", "external_id": sid, "project": os.path.basename(cwd.rstrip("/")) or None,
             "title_if_empty": m.pop("first_prompt") or None, **m}
    try:
        rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": entry})
    except Exception:
        pass


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
    st = {}
    try:
        with open(state_file(cwd)) as f:
            st = json.load(f)
    except Exception:
        st = newest_transcript()  # no plugin hooks here: find this session's transcript ourselves
    if st.get("session_id"):
        e.setdefault("external_id", st["session_id"])
    if st.get("transcript_path") and os.path.exists(st["transcript_path"]):
        m = measure(st["transcript_path"]) or {}
        m.pop("first_prompt", None)
        for k, v in m.items():
            e.setdefault(k, v)
    e.setdefault("project", os.path.basename(cwd.rstrip("/")))
    try:
        sid = rpc("ledger_ingest", {"p_token": TOKEN, "p_entry": e})
        saved = (e.get("human_minutes") or 0) - (e.get("you_minutes") or 0)
        cost = f" · cost ${e['cost_usd']:.2f}" if e.get("cost_usd") is not None else ""
        print(f"ledger: recorded session {sid} · you {e.get('you_minutes')} min · "
              f"human-equivalent {e.get('human_minutes')} min · saved ≈ {round(saved)} min{cost}")
    except Exception as err:
        print(f"ledger: could not record ({err})")


if __name__ == "__main__":
    {"hook": hook, "entry": entry, "keep": keep}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: None)()
