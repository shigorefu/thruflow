"""Optional APNs scheduler. Local notifications remain the delivery fallback."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import math
import os
import signal
from pathlib import Path
import re
import sqlite3
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
import uuid

MAX_BODY = 262_144
MAX_EVENTS = 64
MAX_HORIZON = 366 * 86400
RETRY_WINDOW = 25
MAX_ATTEMPTS = 5
IDENTIFIER = re.compile(r"[A-Za-z0-9._:-]{1,200}\Z")
SECRET = re.compile(r"[0-9a-fA-F]{64}\Z")
TOKEN = re.compile(r"[0-9a-fA-F]{32,512}\Z")
PATH = re.compile(r"/v1/installations/([^/]+)(/schedule)?\Z")


class RequestError(Exception):
    def __init__(self, status: int, code: str):
        self.status, self.code = status, code


def canonical(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def checked_uuid(value: object) -> str:
    if not isinstance(value, str) or len(value) != 36:
        raise RequestError(400, "invalid_uuid")
    try:
        uuid.UUID(value)
    except ValueError:
        raise RequestError(400, "invalid_uuid") from None
    return value


def validate_events(payload: object, now: float) -> tuple[int, list[dict], str]:
    if not isinstance(payload, dict) or set(payload) != {"revision", "events"}:
        raise RequestError(400, "invalid_snapshot")
    revision = payload["revision"]
    events = payload["events"]
    if type(revision) is not int or not 0 <= revision <= 2**63 - 1:
        raise RequestError(400, "invalid_revision")
    if not isinstance(events, list) or len(events) > MAX_EVENTS:
        raise RequestError(400, "invalid_events")
    result, identifiers = [], set()
    for event in events:
        if not isinstance(event, dict) or set(event) != {"identifier", "version", "fireAt", "title", "body", "badge"}:
            raise RequestError(400, "invalid_event")
        identifier = event["identifier"]
        if not isinstance(identifier, str) or not IDENTIFIER.fullmatch(identifier) or identifier in identifiers:
            raise RequestError(400, "invalid_identifier")
        identifiers.add(identifier)
        checked_uuid(event["version"])
        fire_at = event["fireAt"]
        if type(fire_at) not in (int, float) or not math.isfinite(fire_at) or not 0 <= fire_at <= now + MAX_HORIZON:
            raise RequestError(400, "invalid_fire_date")
        if not isinstance(event["title"], str) or len(event["title"].encode()) > 1024:
            raise RequestError(400, "invalid_title")
        if not isinstance(event["body"], str) or len(event["body"].encode()) > 2048:
            raise RequestError(400, "invalid_body")
        if type(event["badge"]) is not int or event["badge"] not in (0, 1):
            raise RequestError(400, "invalid_badge")
        # Stay below APNs's 4 KiB alert payload ceiling including metadata.
        if len(canonical(apns_payload(event)).encode()) > 4000:
            raise RequestError(400, "payload_too_large")
        result.append(dict(event))
    result.sort(key=lambda event: event["identifier"])
    digest = hashlib.sha256(canonical(result).encode()).hexdigest()
    return revision, result, digest


def apns_payload(event: dict) -> dict:
    aps = {"alert": {"title": event["title"], "body": event["body"]},
           "sound": "default", "mutable-content": 1, "content-available": 1}
    if event["badge"]:
        aps["badge"] = event["badge"]
    return {
        "aps": aps,
        "local_identifier": event["identifier"], "event_version": event["version"],
        "fire_at": event["fireAt"],
    }


class Store:
    """One locked SQLite connection; transactions never span the APNs request."""
    def __init__(self, path: str, enrollment_limit: int = 10_000):
        self.lock = threading.RLock()
        self.enrollment_limit = enrollment_limit
        self.db = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.executescript("""
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=FULL;
            PRAGMA foreign_keys=ON;
            PRAGMA busy_timeout=5000;
            CREATE TABLE IF NOT EXISTS installations (
                id TEXT PRIMARY KEY, secret_hash TEXT NOT NULL, token TEXT NOT NULL,
                environment TEXT NOT NULL, platform TEXT NOT NULL,
                revision INTEGER, snapshot_hash TEXT, updated REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS events (
                installation TEXT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
                identifier TEXT NOT NULL, version TEXT NOT NULL, revision INTEGER NOT NULL,
                fire_at REAL NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, badge INTEGER NOT NULL, payload_hash TEXT NOT NULL,
                state TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
                next_attempt REAL NOT NULL, updated REAL NOT NULL,
                PRIMARY KEY (installation, identifier)
            );
            CREATE INDEX IF NOT EXISTS events_due ON events(state, next_attempt);
        """)
        # A process may have stopped after sending. Retrying is at-least-once;
        # event versions and APNs collapse IDs narrow duplicates, not guarantee absence.
        self.db.execute("UPDATE events SET state='queued' WHERE state='sending'")

    @staticmethod
    def secret_hash(secret: str) -> str:
        return hashlib.sha256(secret.encode("ascii")).hexdigest()

    def authenticate(self, installation: str, secret: str) -> sqlite3.Row:
        row = self.db.execute("SELECT * FROM installations WHERE id=?", (installation,)).fetchone()
        digest = self.secret_hash(secret)
        # Do a constant-time digest comparison even for an unknown installation.
        matches = hmac.compare_digest(row["secret_hash"] if row else "0" * 64, digest)
        if row is None or not matches:
            raise RequestError(401, "unauthorized")
        return row

    def register(self, installation: str, secret: str, payload: object, now: float) -> None:
        if not isinstance(payload, dict) or set(payload) != {"token", "environment", "platform"}:
            raise RequestError(400, "invalid_registration")
        token, environment, platform = payload["token"], payload["environment"], payload["platform"]
        if not isinstance(token, str) or not TOKEN.fullmatch(token):
            raise RequestError(400, "invalid_token")
        if environment not in ("sandbox", "production") or platform not in ("macOS", "iOS"):
            raise RequestError(400, "invalid_registration")
        with self.lock:
            self.db.execute("BEGIN IMMEDIATE")
            try:
                row = self.db.execute("SELECT * FROM installations WHERE id=?", (installation,)).fetchone()
                if row is not None:
                    self.authenticate(installation, secret)
                    self.db.execute("UPDATE installations SET token=?,environment=?,platform=?,updated=? WHERE id=?",
                                    (token.lower(), environment, platform, now, installation))
                    if row["token"] != token.lower() or row["environment"] != environment:
                        self.db.execute("UPDATE events SET state='queued' WHERE installation=? AND state='sending'", (installation,))
                else:
                    count = self.db.execute("SELECT count(*) FROM installations").fetchone()[0]
                    if count >= self.enrollment_limit:
                        raise RequestError(503, "enrollment_full")
                    self.db.execute("INSERT INTO installations(id,secret_hash,token,environment,platform,updated) VALUES(?,?,?,?,?,?)",
                                    (installation, self.secret_hash(secret), token.lower(), environment, platform, now))
                self.db.execute("COMMIT")
            except BaseException:
                self.db.execute("ROLLBACK")
                raise

    def replace(self, installation: str, secret: str, payload: object, now: float) -> int:
        revision, events, digest = validate_events(payload, now)
        with self.lock:
            self.db.execute("BEGIN IMMEDIATE")
            try:
                row = self.authenticate(installation, secret)
                if row["revision"] is not None and revision <= row["revision"]:
                    if revision == row["revision"] and hmac.compare_digest(row["snapshot_hash"], digest):
                        self.db.execute("COMMIT")
                        return revision
                    raise RequestError(409, "stale_revision")
                existing = {row["identifier"]: row for row in self.db.execute(
                    "SELECT * FROM events WHERE installation=?", (installation,))}
                incoming = {event["identifier"] for event in events}
                for identifier in existing.keys() - incoming:
                    self.db.execute("UPDATE events SET state='cancelled',title='',body='',revision=?,updated=? WHERE installation=? AND identifier=?",
                                    (revision, now, installation, identifier))
                for event in events:
                    old = existing.get(event["identifier"])
                    payload_hash = hashlib.sha256(canonical(event).encode()).hexdigest()
                    if old is not None and old["version"] == event["version"]:
                        # Versions identify immutable event contents. A terminal event
                        # cannot be resurrected by a later full snapshot.
                        if not hmac.compare_digest(old["payload_hash"], payload_hash):
                            raise RequestError(409, "version_reused")
                        continue
                    state = "queued" if event["fireAt"] + RETRY_WINDOW >= now else "expired"
                    self.db.execute("""INSERT INTO events(installation,identifier,version,revision,fire_at,title,body,badge,payload_hash,state,attempts,next_attempt,updated)
                        VALUES(?,?,?,?,?,?,?,?,?,?,0,?,?) ON CONFLICT(installation,identifier) DO UPDATE SET
                        version=excluded.version,revision=excluded.revision,fire_at=excluded.fire_at,title=excluded.title,
                        body=excluded.body,badge=excluded.badge,payload_hash=excluded.payload_hash,state=excluded.state,attempts=0,
                        next_attempt=excluded.next_attempt,updated=excluded.updated""",
                        (installation, event["identifier"], event["version"], revision, event["fireAt"],
                         event["title"] if state == "queued" else "", event["body"] if state == "queued" else "",
                         event["badge"], payload_hash, state, event["fireAt"], now))
                self.db.execute("UPDATE installations SET revision=?,snapshot_hash=?,updated=? WHERE id=?",
                                (revision, digest, now, installation))
                self.db.execute("COMMIT")
            except BaseException:
                self.db.execute("ROLLBACK")
                raise
        return revision

    def claim(self, now: float) -> dict | None:
        with self.lock:
            # Expire before selecting, so restart/offline periods cannot create late alerts.
            self.db.execute("UPDATE events SET state='expired',title='',body='',updated=? WHERE state IN ('queued','sending') AND fire_at+?<?",
                            (now, RETRY_WINDOW, now))
            row = self.db.execute("""SELECT events.*,installations.token,installations.environment
                FROM events JOIN installations ON events.installation=installations.id
                WHERE events.state='queued' AND events.next_attempt<=? AND installations.token!=''
                ORDER BY events.next_attempt LIMIT 1""", (now,)).fetchone()
            if row is None:
                return None
            event = dict(row)
            self.db.execute("UPDATE events SET state='sending',attempts=attempts+1,updated=? WHERE installation=? AND identifier=? AND version=?",
                            (now, event["installation"], event["identifier"], event["version"]))
            event["attempts"] += 1
            return event

    def current(self, event: dict) -> bool:
        with self.lock:
            return self.db.execute("""SELECT 1 FROM events JOIN installations ON events.installation=installations.id
                WHERE installation=? AND identifier=? AND version=? AND events.revision=? AND state='sending'
                AND installations.token=? AND installations.environment=?""",
                (event["installation"], event["identifier"], event["version"], event["revision"], event["token"], event["environment"])).fetchone() is not None

    def finish(self, event: dict, status: int | None, now: float) -> None:
        with self.lock:
            if not self.current(event):
                return
            retry = status is None or status in (429, 500, 503)
            delay = min(8, 2 ** (event["attempts"] - 1))
            if status == 200:
                state = "sent"
            elif retry and event["attempts"] < MAX_ATTEMPTS and now + delay <= event["fire_at"] + RETRY_WINDOW:
                state = "queued"
            else:
                state = "expired"
            self.db.execute("UPDATE events SET state=?,next_attempt=?,title=CASE WHEN ?='queued' THEN title ELSE '' END,body=CASE WHEN ?='queued' THEN body ELSE '' END,updated=? WHERE installation=? AND identifier=? AND version=? AND revision=?",
                            (state, now + delay, state, state, now, event["installation"], event["identifier"], event["version"], event["revision"]))
            if status == 410:
                self.db.execute("UPDATE installations SET token='' WHERE id=? AND token=?",
                                (event["installation"], event["token"]))

    def revision(self, installation: str, secret: str) -> int:
        with self.lock:
            return self.authenticate(installation, secret)["revision"] or 0

    def maintain(self, now: float) -> None:
        with self.lock:
            self.db.execute("DELETE FROM events WHERE state IN ('sent','cancelled','expired') AND updated<?", (now - 7 * 86400,))
            self.db.execute("DELETE FROM installations WHERE updated<? AND NOT EXISTS (SELECT 1 FROM events WHERE installation=installations.id)",
                            (now - 90 * 86400,))
            self.db.execute("PRAGMA wal_checkpoint(PASSIVE)")


def b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def der_to_raw(signature: bytes) -> bytes:
    """Convert OpenSSL's DER ECDSA sequence to JOSE's fixed-width r||s."""
    if len(signature) < 8 or signature[0] != 0x30 or signature[1] != len(signature) - 2:
        raise ValueError("Invalid ES256 signature")
    offset, numbers = 2, []
    for _ in range(2):
        if offset + 2 > len(signature) or signature[offset] != 0x02:
            raise ValueError("Invalid ES256 integer")
        size = signature[offset + 1]
        value = signature[offset + 2:offset + 2 + size]
        if len(value) != size or not value or value[0] & 0x80:
            raise ValueError("Invalid ES256 integer")
        value = value.lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("Invalid ES256 width")
        numbers.append(value.rjust(32, b"\x00"))
        offset += size + 2
    if offset != len(signature):
        raise ValueError("Invalid ES256 length")
    return b"".join(numbers)


class APNs:
    def __init__(self):
        self.key_path = os.environ.get("APNS_KEY_PATH", "")
        self.key_id = os.environ.get("APNS_KEY_ID", "")
        self.team_id = os.environ.get("APNS_TEAM_ID", "")
        self.topic = os.environ.get("APNS_TOPIC", "com.shigorefu.thruflow")
        self.jwt, self.jwt_at = "", 0.0
        self.lock = threading.Lock()

    @property
    def ready(self) -> bool:
        if not (re.fullmatch(r"[A-Z0-9]{10}", self.key_id) and re.fullmatch(r"[A-Z0-9]{10}", self.team_id)
                and re.fullmatch(r"[A-Za-z0-9.-]{1,200}", self.topic) and self.key_path and Path(self.key_path).is_file()):
            return False
        try:
            self.authorization(time.time())
            return True
        except (OSError, ValueError, subprocess.SubprocessError):
            return False

    def authorization(self, now: float) -> str:
        with self.lock:
            if self.jwt and 0 <= now - self.jwt_at < 45 * 60:
                return self.jwt
            unsigned = b64(canonical({"alg": "ES256", "kid": self.key_id}).encode()) + "." + b64(canonical({"iss": self.team_id, "iat": int(now)}).encode())
            result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", self.key_path], input=unsigned.encode(),
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=3, check=True)
            self.jwt = unsigned + "." + b64(der_to_raw(result.stdout))
            self.jwt_at = now
            return self.jwt

    def send(self, event: dict, now: float) -> int | None:
        if not self.ready:
            return None
        host = "api.sandbox.push.apple.com" if event["environment"] == "sandbox" else "api.push.apple.com"
        payload = apns_payload({"identifier": event["identifier"], "version": event["version"], "fireAt": event["fire_at"],
                                "title": event["title"], "body": event["body"], "badge": event["badge"]})
        collapse_id = hashlib.sha256((event["installation"] + ":" + event["identifier"]).encode()).hexdigest()
        # Every private value travels on stdin rather than in process arguments.
        lines = {
            "url": f"https://{host}/3/device/{event['token']}",
            "request": "POST", "data-binary": canonical(payload),
        }
        config = "".join(f'{key} = {json.dumps(value, ensure_ascii=False)}\n' for key, value in lines.items())
        headers = [f"authorization: bearer {self.authorization(now)}", f"apns-topic: {self.topic}",
                   "apns-push-type: alert", "apns-priority: 10", f"apns-expiration: {int(event['fire_at'] + RETRY_WINDOW)}",
                   f"apns-collapse-id: {collapse_id}", "content-type: application/json"]
        config += "".join(f'header = {json.dumps(header)}\n' for header in headers)
        try:
            result = subprocess.run(["curl", "--http2", "--silent", "--show-error", "--connect-timeout", "2", "--max-time", "5",
                                     "--max-filesize", "65536", "--output", "/dev/null", "--write-out", "%{http_code}", "--config", "-"],
                                    input=config.encode(), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=6, check=False)
            return int(result.stdout) if result.returncode == 0 and re.fullmatch(rb"[0-9]{3}", result.stdout) else None
        except (OSError, subprocess.SubprocessError):
            return None


class Worker:
    def __init__(self, store: Store, apns, clock=time.time):
        self.store, self.apns, self.clock = store, apns, clock
        self.stopped = threading.Event()

    def step(self) -> bool:
        event = self.store.claim(self.clock())
        if event is None:
            return False
        if not self.store.current(event):
            return True
        try:
            status = self.apns.send(event, self.clock())
        except (OSError, ValueError, subprocess.SubprocessError):
            status = None
        self.store.finish(event, status, self.clock())
        return True

    def run(self) -> None:
        maintenance_at = 0
        while not self.stopped.is_set():
            now = self.clock()
            if now >= maintenance_at:
                self.store.maintain(now)
                maintenance_at = now + 3600
            if not self.step():
                self.stopped.wait(0.25)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 32

    def __init__(self, address, store: Store, apns):
        self.store, self.apns = store, apns
        # Bound concurrent request handlers, including slow body readers.
        self.slots = threading.BoundedSemaphore(16)
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()

    def handle_error(self, request, client_address):
        # Never print a request, token, payload, authentication header or traceback.
        pass


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    server_version = "ThruFlowPush/1"
    sys_version = ""

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, format, *args):
        pass

    def response(self, status: int, payload: dict):
        data = canonical(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self.response(200, {"ready": bool(self.server.apns.ready)})
        else:
            self.response(404, {"error": "not_found"})

    def do_PUT(self):
        try:
            match = PATH.fullmatch(urlsplit(self.path).path)
            if match is None or urlsplit(self.path).query:
                raise RequestError(404, "not_found")
            installation = checked_uuid(match.group(1)).lower()
            authorization = self.headers.get("Authorization", "")
            if not authorization.startswith("Bearer ") or not SECRET.fullmatch(authorization[7:]):
                raise RequestError(401, "unauthorized")
            secret = authorization[7:]
            content_length = self.headers.get("Content-Length", "")
            if self.headers.get("Transfer-Encoding") or not re.fullmatch(r"[0-9]{1,8}", content_length):
                raise RequestError(400, "invalid_length")
            length = int(content_length)
            if length > MAX_BODY:
                raise RequestError(413, "body_too_large")
            try:
                body = self.rfile.read(length)
                if len(body) != length:
                    raise RequestError(400, "incomplete_body")
                payload = json.loads(body.decode("utf-8"), parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
            except (UnicodeError, ValueError, RecursionError):
                raise RequestError(400, "invalid_json") from None
            if match.group(2):
                # Authenticate before exposing service readiness.
                with self.server.store.lock:
                    self.server.store.authenticate(installation, secret)
                if not self.server.apns.ready:
                    raise RequestError(503, "provider_unavailable")
                revision = self.server.store.replace(installation, secret, payload, time.time())
                self.response(200, {"accepted": True, "revision": revision})
            else:
                self.server.store.register(installation, secret, payload, time.time())
                self.response(200, {"ready": bool(self.server.apns.ready),
                                    "revision": self.server.store.revision(installation, secret)})
        except RequestError as error:
            self.response(error.status, {"error": error.code})
        except (UnicodeError, ValueError, TypeError, OverflowError):
            self.response(400, {"error": "invalid_payload"})
        except (OSError, sqlite3.Error):
            self.response(503, {"error": "temporarily_unavailable"})


def main():
    os.umask(0o077)
    path = os.environ.get("NOTIFICATION_DB", "/state/notifications.sqlite3")
    store = Store(path, int(os.environ.get("MAX_INSTALLATIONS", "10000")))
    apns = APNs()
    worker = Worker(store, apns)
    thread = threading.Thread(target=worker.run, name="notification-worker", daemon=True)
    thread.start()
    server = Server((os.environ.get("LISTEN_HOST", "0.0.0.0"), int(os.environ.get("LISTEN_PORT", "8080"))), store, apns)
    def stop(_signal, _frame):
        # shutdown must run outside the serve_forever thread.
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        worker.stopped.set()
        thread.join(timeout=7)
        server.server_close()
        store.db.close()


if __name__ == "__main__":
    main()
