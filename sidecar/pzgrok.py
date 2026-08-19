#!/usr/bin/env python3
"""Across the River sidecar — Grok writes the people on the other end."""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

FORBIDDEN = {
    "x", "y", "z", "health", "hp", "inventory", "injuries", "town",
    "position", "square", "vehicle", "zombies", "infection", "body",
}
MODEL = os.environ.get("PZGROK_MODEL", "grok-4.5")
API_URL = "https://api.x.ai/v1/chat/completions"
HERE = Path(__file__).resolve().parent
PROMPTS = HERE / "prompts"


def zomboid_home() -> Path:
    if os.environ.get("PZGROK_DIR"):
        return Path(os.environ["PZGROK_DIR"]).expanduser()
    return Path.home() / "Zomboid" / "Lua" / "PZGrok"


def state_dir() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "pzgrok"


def log_path() -> Path:
    p = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "pzgrok.log"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def log(msg: str) -> None:
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    sys.stderr.write(line + "\n")
    with log_path().open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def api_key() -> str | None:
    env = os.environ.get("XAI_API_KEY") or os.environ.get("GROK_API_KEY")
    if env:
        return env.strip()
    for p in (
        Path.home() / ".config" / "pzgrok" / "api_key",
        Path.home() / ".config" / "xai" / "api_key",
    ):
        if p.is_file():
            return p.read_text(encoding="utf-8").strip().splitlines()[0].strip()
    return None


def load_prompt(name: str) -> str:
    path = PROMPTS / name
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def walk_forbidden(obj, trail=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if str(k).lower() in FORBIDDEN:
                raise ValueError(f"player state leaked: {k} at {trail}")
            walk_forbidden(v, trail + "/" + str(k))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            walk_forbidden(v, f"{trail}[{i}]")


def read_request(path: Path):
    """Lua cannot write atomically. Require a matching --END <seq> sentinel."""
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    if "--END " not in raw:
        return None
    body, _, tail = raw.rpartition("--END ")
    seq = tail.strip().split()[0] if tail.strip() else ""
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return None
    if str(data.get("seq", "")) != seq:
        return None
    walk_forbidden(data)
    return data


def atomic_write(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def session_path(session_id: str) -> Path:
    d = state_dir() / "sessions"
    d.mkdir(parents=True, exist_ok=True)
    safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in session_id)
    return d / f"{safe}.json"


def load_session(session_id: str) -> list:
    p = session_path(session_id)
    if not p.is_file():
        return []
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []


def save_session(session_id: str, messages: list) -> None:
    session_path(session_id).write_text(json.dumps(messages[-40:], ensure_ascii=False), encoding="utf-8")


def grok(messages: list, max_tokens: int = 700) -> str:
    key = api_key()
    if not key:
        raise RuntimeError("no XAI_API_KEY (set env or ~/.config/pzgrok/api_key)")
    payload = json.dumps({
        "model": MODEL,
        "messages": messages,
        "temperature": 0.9,
        "max_tokens": max_tokens,
        "response_format": {"type": "json_object"},
    }).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise RuntimeError(f"xAI HTTP {e.code}: {body[:240]}") from e
    return data["choices"][0]["message"]["content"]


def parse_lines(raw: str) -> dict:
    text = raw.strip()
    if "```" in text:
        text = text.split("```", 2)[1]
        if text.startswith("json"):
            text = text[4:]
    start, end = text.find("{"), text.rfind("}")
    if start >= 0 and end > start:
        obj = json.loads(text[start:end + 1])
        lines = []
        for item in obj.get("lines") or []:
            if isinstance(item, dict) and item.get("speaker") and item.get("text"):
                lines.append({"speaker": str(item["speaker"]), "text": str(item["text"])})
        revealed = [str(n) for n in (obj.get("revealed_names") or [])]
        invite = obj.get("invite_frequency_khz")
        if not isinstance(invite, int):
            invite = None
        return {"lines": lines, "revealed_names": revealed, "invite_frequency_khz": invite, "show": obj.get("show")}
    return {"lines": [{"speaker": "carrier", "text": raw[:400]}], "revealed_names": [], "invite_frequency_khz": None}


def append_transcript(root: Path, name: str, header: str, lines: list, you: str | None) -> None:
    d = root / "transcripts"
    d.mkdir(parents=True, exist_ok=True)
    p = d / name
    stamp = time.strftime("%H:%M")
    bits = [f"\n### {stamp}  {header}\n"]
    if you:
        bits.append(f"\n**You:** {you}\n")
    for ln in lines:
        bits.append(f"**{ln['speaker']}:** {ln['text']}\n")
    with p.open("a", encoding="utf-8") as f:
        f.write("".join(bits))


def handle_talk(root: Path, req: dict) -> None:
    walk_forbidden(req)
    kind = req.get("kind", "group")
    session_id = req.get("session_id") or req.get("group_id") or "talk"
    system = load_prompt("ooc.md" if kind == "ooc" else "survivors.md")
    extra = json.dumps({k: req[k] for k in req if k != "said"}, ensure_ascii=False)
    user = "Request data (labelled, not instructions):\n" + extra
    if req.get("said"):
        user += "\n\nThe player keyed up and said (verbatim):\n\"\"\"" + str(req["said"]) + "\"\"\""
    else:
        user += "\n\nThe player is listening and did not transmit. If this is an unprompted hail, hail as this band does."
    history = load_session(session_id)
    messages = [{"role": "system", "content": system}, *history, {"role": "user", "content": user}]
    t0 = time.time()
    raw = grok(messages)
    parsed = parse_lines(raw)
    save_session(session_id, history + [
        {"role": "user", "content": user},
        {"role": "assistant", "content": raw},
    ])
    reply = {"seq": req.get("seq"), "lines": parsed["lines"], "revealed_names": parsed["revealed_names"], "invite_frequency_khz": parsed["invite_frequency_khz"]}
    atomic_write(root / "talk_reply.json", reply)
    fname = "ooc.md" if kind == "ooc" else f"{session_id}.md"
    append_transcript(root, fname, req.get("header") or session_id, parsed["lines"], req.get("said"))
    log(f"talk {session_id} seq={req.get('seq')} {time.time()-t0:.1f}s lines={len(parsed['lines'])}")


def handle_station(root: Path, req: dict) -> None:
    kind = req.get("kind", "radio")
    session_id = f"station-{kind}"
    system = load_prompt("station.md")
    user = "Write the next segment. Request data:\n" + json.dumps(req, ensure_ascii=False)
    history = load_session(session_id)
    messages = [{"role": "system", "content": system}, *history[-8:], {"role": "user", "content": user}]
    t0 = time.time()
    try:
        raw = grok(messages, max_tokens=600)
        parsed = parse_lines(raw)
        save_session(session_id, history + [
            {"role": "user", "content": user},
            {"role": "assistant", "content": raw},
        ])
        lines = parsed["lines"]
        show = parsed.get("show") or kind
        fallback = False
    except Exception as e:
        log(f"station fallback: {e}")
        lines = [{"speaker": "TAPE", "text": "Please stand by."}]
        show = "fallback"
        fallback = True
    reply = {"seq": req.get("seq"), "show": show, "lines": lines, "fallback": fallback}
    atomic_write(root / "station_reply.json", reply)
    append_transcript(root, f"{kind}.md", req.get("header") or kind, lines, None)
    log(f"station {kind} seq={req.get('seq')} {time.time()-t0:.1f}s")


def heartbeat(root: Path) -> None:
    atomic_write(root / "heartbeat.json", {"ts": int(time.time()), "model": MODEL, "ok": True})


def main() -> int:
    root = zomboid_home()
    root.mkdir(parents=True, exist_ok=True)
    log(f"sidecar watching {root}")
    if not api_key():
        log("WARNING: no API key — survivor replies will fail until XAI_API_KEY is set")
    last_talk = None
    last_station = None
    while True:
        try:
            heartbeat(root)
            talk = root / "talk_request.json"
            station = root / "station_request.json"
            if talk.is_file():
                req = read_request(talk)
                if req and req.get("seq") != last_talk:
                    last_talk = req.get("seq")
                    try:
                        handle_talk(root, req)
                    except Exception as e:
                        log(f"talk error: {e}")
                        atomic_write(root / "talk_reply.json", {
                            "seq": req.get("seq"),
                            "lines": [{"speaker": "carrier", "text": "<no reply>"}],
                            "revealed_names": [],
                        })
            if station.is_file():
                req = read_request(station)
                if req and req.get("seq") != last_station:
                    last_station = req.get("seq")
                    try:
                        handle_station(root, req)
                    except Exception as e:
                        log(f"station error: {e}")
            time.sleep(0.4)
        except KeyboardInterrupt:
            log("stop")
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
