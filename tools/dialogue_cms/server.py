"""Local-only dialogue editor server. No third-party dependencies or cloud API."""
from __future__ import annotations

import json
import os
import re
import tempfile
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from characters import load_catalog, validate_catalog, save_catalog_and_dialogues

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "dialogues" / "dialogues.json"
INDEX = Path(__file__).with_name("index.html")
def resident_ids():
    return {row["id"] for row in validate_catalog(load_catalog())["characters"]}
MISSIONS = {
    "all", "strength", "outside", "conversation", "movement", "sittingBreak",
    "food", "hobby", "weeklyStrength", "weeklyActive", "weeklyTogether",
    "weeklyLearn", "monthlyCommunity", "monthlyHabit", "monthlyReview",
}


def require_keys(obj, keys, location):
    if not isinstance(obj, dict) or set(obj) != set(keys):
        raise ValueError(f"{location}: invalid fields")


def whole_number(value, minimum, maximum):
    return type(value) is int and minimum <= value <= maximum


def date_full(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("Invalid YYYY-MM-DD")
    if date.fromisoformat(value).isoformat() != value:
        raise ValueError("Invalid calendar date")


def month_day(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{2}-\d{2}", value):
        raise ValueError("Invalid MM-DD")
    date_full("2000-" + value)  # Leap day can be an annual event.


def validate(doc, residents=None):
    if residents is None:
        residents = resident_ids()
    require_keys(doc, {"version", "dialogues"}, "root")
    if doc["version"] != 1 or type(doc["version"]) is not int:
        raise ValueError("Unsupported dialogue version")
    rows = doc["dialogues"]
    if not isinstance(rows, list) or not rows:
        raise ValueError("Dialogues must be a nonempty list")
    ids = set()
    defaults = set()
    for i, entry in enumerate(rows):
        require_keys(entry, {"id", "residentId", "text", "priority",
                              "once", "logic", "conditions"}, f"dialogues[{i}]")
        identifier = entry["id"]
        if not isinstance(identifier, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", identifier):
            raise ValueError(f"Invalid id at row {i}")
        if identifier in ids:
            raise ValueError(f"Duplicate dialogue id: {identifier}")
        ids.add(identifier)
        if entry["residentId"] not in residents:
            raise ValueError(f"Unknown resident: {identifier}")
        if not isinstance(entry["text"], str) or not entry["text"].strip() or len(entry["text"]) > 500:
            raise ValueError(f"Invalid text: {identifier}")
        if not whole_number(entry["priority"], -1000, 1000):
            raise ValueError(f"Invalid priority: {identifier}")
        if type(entry["once"]) is not bool or entry["logic"] not in {"all", "any"}:
            raise ValueError(f"Invalid once/logic: {identifier}")
        conditions = entry["conditions"]
        if not isinstance(conditions, list) or len(conditions) > 8:
            raise ValueError(f"Invalid conditions: {identifier}")
        if not conditions and not entry["once"]:
            defaults.add(entry["residentId"])
        for j, condition in enumerate(conditions):
            loc = f"{identifier}.conditions[{j}]"
            if not isinstance(condition, dict):
                raise ValueError(f"Invalid condition: {loc}")
            kind = condition.get("type")
            if kind == "mission":
                require_keys(condition, {"type", "missionId", "minCount"}, loc)
                if condition["missionId"] not in MISSIONS or not whole_number(condition["minCount"], 1, 1000000):
                    raise ValueError(f"Invalid mission count: {loc}")
            elif kind == "kotohogi":
                require_keys(condition, {"type", "min"}, loc)
                if not whole_number(condition["min"], 0, 10000000):
                    raise ValueError(f"Invalid kotohogi: {loc}")
            elif kind == "date":
                mode = condition.get("mode")
                if mode == "exact":
                    require_keys(condition, {"type", "mode", "date"}, loc)
                    date_full(condition["date"])
                elif mode == "range":
                    require_keys(condition, {"type", "mode", "start", "end"}, loc)
                    date_full(condition["start"])
                    date_full(condition["end"])
                    if condition["start"] > condition["end"]:
                        raise ValueError(f"Reversed range: {loc}")
                elif mode == "annual":
                    require_keys(condition, {"type", "mode", "date"}, loc)
                    month_day(condition["date"])
                elif mode == "annual_range":
                    require_keys(condition, {"type", "mode", "start", "end"}, loc)
                    month_day(condition["start"])
                    month_day(condition["end"])
                elif mode == "weekday":
                    require_keys(condition, {"type", "mode", "days"}, loc)
                    days = condition["days"]
                    if not isinstance(days, list) or not days or len(set(map(str, days))) != len(days) or not all(whole_number(d, 1, 7) for d in days):
                        raise ValueError(f"Invalid weekdays: {loc}")
                else:
                    raise ValueError(f"Invalid date mode: {loc}")
            else:
                raise ValueError(f"Unknown condition type: {loc}")
    if defaults != residents:
        raise ValueError(f"Every resident needs an unconditional non-once dialogue. Missing: {sorted(residents - defaults)}")
    return doc


def write_document(doc):
    validate(doc)
    DATA.parent.mkdir(parents=True, exist_ok=True)
    # Atomic overwrite after validation, never truncate the prior good file.
    payload = json.dumps(doc, ensure_ascii=False, indent=2) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=DATA.parent,
                                     prefix=".dialogues-", suffix=".tmp",
                                     delete=False) as tmp:
        name = tmp.name
        try:
            tmp.write(payload)
            tmp.flush()
            os.fsync(tmp.fileno())
        except BaseException:
            os.unlink(name)
            raise
    try:
        os.replace(name, DATA)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class Handler(BaseHTTPRequestHandler):
    def _headers(self, code, mime="application/json; charset=utf-8", size=0):
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(size))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.end_headers()

    def _send(self, code, value):
        content = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self._headers(code, size=len(content))
        self.wfile.write(content)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/":
            raw = INDEX.read_bytes()
            self._headers(200, "text/html; charset=utf-8", len(raw))
            self.wfile.write(raw)
        elif path == "/api/characters":
            try:
                document = validate_catalog(load_catalog())
                self._send(200, document)
            except (OSError, ValueError, TypeError) as exc:
                self._send(500, {"error": str(exc)})
        elif path == "/api/dialogues":
            try:
                document = json.loads(DATA.read_text(encoding="utf-8"))
                validate(document)
                self._send(200, document)
            except (OSError, ValueError, TypeError) as exc:
                self._send(500, {"error": str(exc)})
        else:
            self._send(404, {"error": "Not found"})

    def do_PUT(self):
        endpoint = urlsplit(self.path).path
        if endpoint not in {"/api/dialogues", "/api/cms"}:
            return self._send(404, {"error": "Not found"})
        # A cross-origin website must not be able to modify local files.
        expected = f"http://127.0.0.1:{self.server.server_port}"
        if self.headers.get("Origin") != expected:
            return self._send(403, {"error": "Same-origin editor only"})
        if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
            return self._send(415, {"error": "JSON required"})
        try:
            size = int(self.headers.get("Content-Length", "-1"))
            if not 0 < size <= 1024 * 1024:
                return self._send(413, {"error": "Invalid document size"})
            raw = self.rfile.read(size)
            value = json.loads(raw.decode("utf-8"))
            if endpoint == "/api/cms":
                result = save_catalog_and_dialogues(value, validate)
                self._send(200, result)
            else:
                write_document(value)
                self._send(200, {"ok": True, "count": len(value["dialogues"])})
        except (ValueError, TypeError, UnicodeDecodeError) as exc:
            self._send(400, {"error": str(exc)})
        except OSError as exc:
            self._send(500, {"error": str(exc)})

    def do_POST(self):
        self._send(405, {"error": "Method not allowed"})


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Kotohogu local dialogue CMS")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("Invalid port")
    if not INDEX.exists() or not DATA.exists() or not (ROOT / "assets/characters/characters.json").exists():
        raise SystemExit("CMS HTML or dialogues.json not found")
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        print(f"Open http://127.0.0.1:{args.port} (Ctrl+C to stop)", flush=True)
        server.serve_forever()
