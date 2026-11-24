import http.client
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import uuid

import server

SECRET = "a" * 64
OTHER_SECRET = "b" * 64
TOKEN = "c" * 64
INSTALLATION = str(uuid.uuid4())
REGISTRATION = {"token": TOKEN, "environment": "sandbox", "platform": "macOS"}


def event(fire_at=1000, identifier="flow.focusFinished.test", version=None, **changes):
    value = {"identifier": identifier, "version": version or str(uuid.uuid4()), "fireAt": fire_at,
             "title": "Focus finished", "body": "", "badge": 1}
    value.update(changes)
    return value


def snapshot(events, revision=1):
    return {"revision": revision, "events": events}


class FakeAPNs:
    def __init__(self, responses=None, ready=True):
        self.ready = ready
        self.responses = list(responses or [200])
        self.sent = []
        self.before_send = None

    def send(self, value, now):
        self.sent.append(dict(value))
        if self.before_send:
            self.before_send(value)
        return self.responses.pop(0) if self.responses else 503


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.store = server.Store(":memory:")
        self.store.register(INSTALLATION, SECRET, REGISTRATION, 999)

    def tearDown(self):
        self.store.db.close()

    def row(self):
        return self.store.db.execute("SELECT * FROM events").fetchone()

    def test_authentication_is_per_installation_and_secret_is_hashed(self):
        self.assertNotEqual(self.store.db.execute("SELECT secret_hash FROM installations").fetchone()[0], SECRET)
        with self.assertRaises(server.RequestError) as error:
            self.store.replace(INSTALLATION, OTHER_SECRET, snapshot([]), 999)
        self.assertEqual(error.exception.status, 401)
        with self.assertRaises(server.RequestError):
            self.store.replace(str(uuid.uuid4()), SECRET, snapshot([]), 999)
        self.assertIsNone(self.store.db.execute("SELECT revision FROM installations").fetchone()[0])

    def test_snapshot_strict_revision_idempotence_and_reordered_event_equivalence(self):
        events = [event(), event(identifier="task.reminder.test")]
        self.store.replace(INSTALLATION, SECRET, snapshot(events, 2), 999)
        self.store.replace(INSTALLATION, SECRET, snapshot(list(reversed(events)), 2), 999)
        for value in (snapshot([], 1), snapshot([], 2)):
            with self.assertRaises(server.RequestError) as error:
                self.store.replace(INSTALLATION, SECRET, value, 999)
            self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.store.db.execute("SELECT count(*) FROM events").fetchone()[0], 2)

    def test_cancel_tombstone_blocks_old_snapshot_and_claimed_completion(self):
        value = event()
        self.store.replace(INSTALLATION, SECRET, snapshot([value]), 999)
        claimed = self.store.claim(1000)
        self.store.replace(INSTALLATION, SECRET, snapshot([], 2), 1000)
        self.assertFalse(self.store.current(claimed))
        self.store.finish(claimed, 200, 1000)
        self.assertEqual(self.row()["state"], "cancelled")
        self.assertEqual(self.row()["title"], "")
        with self.assertRaises(server.RequestError):
            self.store.replace(INSTALLATION, SECRET, snapshot([value]), 1000)

    def test_reschedule_guard_preserves_new_generation_when_old_send_finishes(self):
        old, new = event(), event(fire_at=1010)
        self.store.replace(INSTALLATION, SECRET, snapshot([old]), 999)
        claimed = self.store.claim(1000)
        self.store.replace(INSTALLATION, SECRET, snapshot([new], 2), 1000)
        self.store.finish(claimed, 200, 1000)
        self.assertEqual(self.row()["version"], new["version"])
        self.assertEqual(self.row()["state"], "queued")
        self.assertIsNone(self.store.claim(1000))

    def test_sent_content_is_purged_and_same_version_is_not_resent(self):
        value = event(body="Temporary contents")
        self.store.replace(INSTALLATION, SECRET, snapshot([value]), 999)
        claimed = self.store.claim(1000)
        self.store.finish(claimed, 200, 1000)
        self.assertEqual((self.row()["title"], self.row()["body"]), ("", ""))
        self.store.replace(INSTALLATION, SECRET, snapshot([value], 2), 1001)
        self.assertIsNone(self.store.claim(1001))
        changed = dict(value, title="changed")
        with self.assertRaises(server.RequestError):
            self.store.replace(INSTALLATION, SECRET, snapshot([changed], 3), 1001)

    def test_failed_snapshot_rolls_back_cancellation(self):
        first, second = event(), event(identifier="task.reminder.test")
        self.store.replace(INSTALLATION, SECRET, snapshot([first, second]), 999)
        with self.assertRaises(server.RequestError):
            self.store.replace(INSTALLATION, SECRET, snapshot([dict(first, title="different")], 2), 999)
        rows = self.store.db.execute("SELECT state FROM events").fetchall()
        self.assertEqual([row[0] for row in rows], ["queued", "queued"])

    def test_token_rotation_invalidates_claim_and_requeues_current_event(self):
        self.store.replace(INSTALLATION, SECRET, snapshot([event()]), 999)
        claimed = self.store.claim(1000)
        self.store.register(INSTALLATION, SECRET, dict(REGISTRATION, token="d" * 64), 1000)
        self.assertFalse(self.store.current(claimed))
        again = self.store.claim(1000)
        self.assertEqual(again["token"], "d" * 64)

    def test_enrollment_cap_existing_registration_and_other_installation_isolation(self):
        self.store.enrollment_limit = 1
        self.store.register(INSTALLATION, SECRET, REGISTRATION, 1000)
        with self.assertRaises(server.RequestError) as error:
            self.store.register(str(uuid.uuid4()), OTHER_SECRET, REGISTRATION, 1000)
        self.assertEqual(error.exception.code, "enrollment_full")
        self.store.enrollment_limit = 2
        other = str(uuid.uuid4())
        self.store.register(other, OTHER_SECRET, REGISTRATION, 1000)
        self.store.replace(INSTALLATION, SECRET, snapshot([event()]), 1000)
        self.store.replace(other, OTHER_SECRET, snapshot([]), 1000)
        self.assertEqual(self.row()["state"], "queued")

    def test_expiration_and_retention_remove_sensitive_contents(self):
        self.store.replace(INSTALLATION, SECRET, snapshot([event()]), 999)
        self.assertIsNone(self.store.claim(1026))
        self.assertEqual(self.row()["state"], "expired")
        self.assertEqual(self.row()["title"], "")
        self.store.maintain(1026 + 8 * 86400)
        self.assertEqual(self.store.db.execute("SELECT count(*) FROM events").fetchone()[0], 0)
        self.store.maintain(1026 + 91 * 86400)
        self.assertEqual(self.store.db.execute("SELECT count(*) FROM installations").fetchone()[0], 0)

    def test_restart_recovers_claim_but_respects_deadline(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = str(Path(temporary) / "queue.sqlite3")
            store = server.Store(path)
            store.register(INSTALLATION, SECRET, REGISTRATION, 999)
            store.replace(INSTALLATION, SECRET, snapshot([event()]), 999)
            store.claim(1000)
            store.db.close()
            store = server.Store(path)
            self.assertIsNotNone(store.claim(1001))
            store.db.close()
            store = server.Store(path)
            self.assertIsNone(store.claim(1026))
            store.db.close()


class ValidationTests(unittest.TestCase):
    def test_limits_and_nonfinite_dates(self):
        invalid_events = [event(fire_at=float("nan")), event(fire_at=float("inf")), event(fire_at=-1),
                          event(fire_at=server.MAX_HORIZON + 1001), event(identifier="bad/identifier"),
                          event(version="wrong"), event(title="x" * 1025), event(body="x" * 2049), event(badge=True)]
        for value in invalid_events:
            with self.subTest(value=value), self.assertRaises(server.RequestError):
                server.validate_events(snapshot([value]), 1000)
        for value in [snapshot([event()] * 2), snapshot([event(identifier=str(i)) for i in range(65)]),
                      snapshot([], True), snapshot([], 2**63), snapshot([], -1)]:
            with self.assertRaises(server.RequestError):
                server.validate_events(value, 1000)

    def test_apns_payload_has_matching_version_and_original_time(self):
        value = event(title="お疲れ様です。")
        payload = server.apns_payload(value)
        self.assertEqual(payload["local_identifier"], value["identifier"])
        self.assertEqual(payload["event_version"], value["version"])
        self.assertEqual(payload["fire_at"], value["fireAt"])
        self.assertEqual(payload["aps"]["mutable-content"], 1)
        self.assertEqual(payload["aps"]["badge"], 1)
        task = event(identifier="task.reminder.test.delivery." + str(uuid.uuid4()), badge=0)
        server.validate_events(snapshot([task]), 1000)
        self.assertNotIn("badge", server.apns_payload(task)["aps"])

    def test_der_conversion_zero_padding_and_rejection(self):
        r, s = b"\x00\x80" + b"a" * 31, b"\x01" * 31
        signature = b"\x30" + bytes([4 + len(r) + len(s)]) + b"\x02" + bytes([len(r)]) + r + b"\x02" + bytes([len(s)]) + s
        raw = server.der_to_raw(signature)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[:32], r[1:])
        self.assertEqual(raw[32:], b"\x00" + s)
        for invalid in (b"", b"\x30\x02\x02\x00", signature + b"\x00"):
            with self.assertRaises(ValueError):
                server.der_to_raw(invalid)

    def test_real_openssl_es256_jwt_roundtrip(self):
        import base64
        with tempfile.TemporaryDirectory() as temporary:
            key = Path(temporary) / "fixture.p8"
            public = Path(temporary) / "fixture.pub"
            subprocess.run(["openssl", "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", str(key)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["openssl", "pkey", "-in", str(key), "-pubout", "-out", str(public)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            with patch.dict(os.environ, {"APNS_KEY_PATH": str(key), "APNS_KEY_ID": "ABCDEFGHIJ", "APNS_TEAM_ID": "ABCDEFGHIJ"}, clear=True):
                apns = server.APNs()
                self.assertTrue(apns.ready)
                token = apns.authorization(time.time())
            header, claims, signature = token.split(".")
            decode = lambda value: base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
            self.assertEqual(json.loads(decode(header)), {"alg": "ES256", "kid": "ABCDEFGHIJ"})
            self.assertEqual(json.loads(decode(claims))["iss"], "ABCDEFGHIJ")
            raw = decode(signature)
            self.assertEqual(len(raw), 64)
            def integer(value):
                value = value.lstrip(b"\x00") or b"\x00"
                if value[0] & 0x80:
                    value = b"\x00" + value
                return b"\x02" + bytes([len(value)]) + value
            encoded = integer(raw[:32]) + integer(raw[32:])
            der = b"\x30" + bytes([len(encoded)]) + encoded
            signature_path = Path(temporary) / "fixture.sig"
            signature_path.write_bytes(der)
            verified = subprocess.run(["openssl", "dgst", "-sha256", "-verify", str(public), "-signature", str(signature_path)],
                                      input=(header + "." + claims).encode(), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            self.assertEqual(verified.returncode, 0)

    def test_no_credentials_not_ready_and_curl_private_values_use_stdin(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(server.APNs().ready)
        apns = server.APNs()
        apns.jwt, apns.jwt_at = "private.jwt.value", 1000
        value = dict(event(title="通知"), installation=INSTALLATION, token=TOKEN, environment="sandbox", fire_at=1000)
        with patch.object(server.APNs, "ready", new_callable=unittest.mock.PropertyMock, return_value=True), \
             patch.object(server.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"200")) as run:
            self.assertEqual(apns.send(value, 1000), 200)
        args, kwargs = run.call_args
        self.assertNotIn(TOKEN, " ".join(args[0]))
        self.assertNotIn(apns.jwt, " ".join(args[0]))
        self.assertIn(TOKEN.encode(), kwargs["input"])
        self.assertIn("通知".encode(), kwargs["input"])
        self.assertNotIn(b"\\u901a", kwargs["input"])


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.store = server.Store(":memory:")
        self.store.register(INSTALLATION, SECRET, REGISTRATION, 999)
        self.store.replace(INSTALLATION, SECRET, snapshot([event()]), 999)
        self.now = 1000

    def tearDown(self):
        self.store.db.close()

    def test_retry_is_bounded_and_ends_before_local_grace(self):
        apns = FakeAPNs([503] * 10)
        worker = server.Worker(self.store, apns, lambda: self.now)
        for due in (1000, 1001, 1003, 1007, 1015):
            self.now = due
            self.assertTrue(worker.step())
        self.now = 1024
        self.assertFalse(worker.step())
        row = self.store.db.execute("SELECT * FROM events").fetchone()
        self.assertEqual((len(apns.sent), row["state"], row["body"]), (5, "expired", ""))

    def test_permanent_failure_does_not_retry(self):
        apns = FakeAPNs([400])
        worker = server.Worker(self.store, apns, lambda: self.now)
        worker.step()
        self.now += 1
        self.assertFalse(worker.step())
        self.assertEqual(len(apns.sent), 1)

    def test_cancellation_while_transport_inflight_does_not_restore_event(self):
        apns = FakeAPNs()
        apns.before_send = lambda _: self.store.replace(INSTALLATION, SECRET, snapshot([], 2), self.now)
        worker = server.Worker(self.store, apns, lambda: self.now)
        worker.step()
        self.assertEqual(self.store.db.execute("SELECT state FROM events").fetchone()[0], "cancelled")
        self.assertFalse(worker.step())

    def test_unregistered_token_is_disabled_without_affecting_other_installations(self):
        apns = FakeAPNs([410])
        server.Worker(self.store, apns, lambda: self.now).step()
        self.assertEqual(self.store.db.execute("SELECT token FROM installations").fetchone()[0], "")

    def test_overdue_restart_never_sends(self):
        apns = FakeAPNs()
        self.now = 1026
        self.assertFalse(server.Worker(self.store, apns, lambda: self.now).step())
        self.assertEqual(apns.sent, [])


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.store = server.Store(":memory:")
        self.apns = FakeAPNs(ready=False)
        self.http = server.Server(("127.0.0.1", 0), self.store, self.apns)
        self.thread = threading.Thread(target=lambda: self.http.serve_forever(poll_interval=0.01), daemon=True)
        self.thread.start()
        self.path = "/v1/installations/" + INSTALLATION

    def tearDown(self):
        self.http.shutdown()
        self.thread.join(timeout=2)
        self.http.server_close()
        self.store.db.close()

    def request(self, method, path, payload=None, secret=SECRET, raw=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.http.server_port, timeout=3)
        data = raw if raw is not None else json.dumps(payload).encode() if payload is not None else None
        conn.request(method, path, body=data, headers={"Authorization": "Bearer " + secret, "Content-Type": "application/json"})
        response = conn.getresponse()
        result = response.status, json.loads(response.read())
        conn.close()
        return result

    def test_readiness_false_registers_but_never_acknowledges_schedule(self):
        self.assertEqual(self.request("GET", "/health"), (200, {"ready": False}))
        self.assertEqual(self.request("PUT", self.path, REGISTRATION), (200, {"ready": False, "revision": 0}))
        status, body = self.request("PUT", self.path + "/schedule", snapshot([]))
        self.assertEqual((status, body["error"]), (503, "provider_unavailable"))
        self.assertIsNone(self.store.db.execute("SELECT revision FROM installations").fetchone()[0])

    def test_authentication_precedes_readiness_and_cannot_replace_registration(self):
        self.request("PUT", self.path, REGISTRATION)
        for path, payload in [(self.path, REGISTRATION), (self.path + "/schedule", snapshot([]))]:
            self.assertEqual(self.request("PUT", path, payload, secret=OTHER_SECRET)[0], 401)
        self.assertEqual(self.request("PUT", self.path + "/schedule", snapshot([]), secret="short")[0], 401)

    def test_validated_snapshot_ack_revision_idempotence_and_cancel(self):
        self.apns.ready = True
        self.assertEqual(self.request("PUT", self.path, REGISTRATION), (200, {"ready": True, "revision": 0}))
        value = snapshot([event(fire_at=time.time() + 10)])
        self.assertEqual(self.request("PUT", self.path + "/schedule", value), (200, {"accepted": True, "revision": 1}))
        self.assertEqual(self.request("PUT", self.path + "/schedule", value)[0], 200)
        self.assertEqual(self.request("PUT", self.path + "/schedule", snapshot([]))[0], 409)
        self.assertEqual(self.request("PUT", self.path + "/schedule", snapshot([], 2))[0], 200)
        self.assertEqual(self.store.db.execute("SELECT state FROM events").fetchone()[0], "cancelled")
        self.assertEqual(self.request("PUT", self.path, REGISTRATION), (200, {"ready": True, "revision": 2}))

    def test_malformed_json_unicode_size_and_route_are_bounded(self):
        self.assertEqual(self.request("PUT", self.path, raw=b"{broken")[0], 400)
        self.assertEqual(self.request("PUT", self.path, raw=b"x" * (server.MAX_BODY + 1))[0], 413)
        self.assertEqual(self.request("PUT", self.path + "?debug=1", REGISTRATION)[0], 404)
        self.assertEqual(self.request("GET", "/v1/installations/anything")[0], 404)
        self.apns.ready = True
        self.request("PUT", self.path, REGISTRATION)
        invalid = snapshot([event(title="\ud800")])
        self.assertEqual(self.request("PUT", self.path + "/schedule", invalid)[0], 400)


if __name__ == "__main__":
    unittest.main()
