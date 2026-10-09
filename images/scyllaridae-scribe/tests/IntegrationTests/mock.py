import base64
import hashlib
import hmac
import json
import signal
import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OPERATION = "a" * 32
REFERENCE = "12345678-1234-1234-1234-123456789abc"
IMAGE = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=")
HOCR = b'<html><body><div class="ocr_page">published</div></body></html>'


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    reject_callback = False
    callbacks = 0

    def respond(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/image.png":
            self.respond(200, IMAGE, "image/png")
        elif self.path == "/callbacks":
            self.respond(200, json.dumps({"count": Handler.callbacks}).encode())
        else:
            self.respond(404, b"{}")

    def do_HEAD(self):
        self.send_response(200 if self.path == "/image.png" else 404)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(IMAGE)))
        self.end_headers()

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path == "/reject":
            Handler.reject_callback = True
            self.respond(200, b"{}")
            return
        try:
            request = json.loads(raw)
            if self.path == "/islandora-scribe/correlation":
                assert request == dict(operationId=OPERATION, externalReferenceId=REFERENCE,
                                       workspaceId=42, itemId="item-1", itemImageId=7, contextId="55")
                signed = self.headers["X-Scribe-Timestamp"].encode() + b"." + raw
                signature = hmac.new(b"01234567890123456789012345678901", signed, hashlib.sha256).hexdigest()
                assert hmac.compare_digest(self.headers["X-Scribe-Signature"], "v1=" + signature)
                Handler.callbacks += 1
                self.respond(503 if Handler.reject_callback else 200, b"{}")
                return
            assert self.headers["X-Scribe-API-Key"] == "test-only"
            assert self.headers["X-Scribe-Workspace-ID"] == "42"
            method = self.path.rsplit("/", 1)[-1]
            if method == "StartUploadBatch":
                assert request["batchId"] == OPERATION
                assert request["externalReferenceId"] == REFERENCE
                assert request["contextId"] == "55"
                assert request["files"][0]["contentSha256"] == hashlib.sha256(IMAGE).hexdigest()
                response = {"item": {"id": "item-1"}}
            elif method == "UploadItemImage":
                assert request["batchId"] == OPERATION
                assert base64.b64decode(request["imageData"]) == IMAGE
                response = {"image": {"id": "7"}, "transcriptionJobId": "9"}
            elif method == "GetTranscriptionJob":
                assert request["jobId"] == "9"
                response = {"job": {"status": "TRANSCRIPTION_JOB_STATUS_COMPLETED"}}
            elif method == "GetAnnotationPage":
                assert request["itemImageId"] == "7"
                response = {"revision": "3"}
            elif method == "ExportAnnotationPage":
                assert request == dict(itemImageId="7", expectedRevision="3", format="ANNOTATION_EXPORT_FORMAT_HOCR")
                response = {"content": base64.b64encode(HOCR).decode()}
            else:
                raise AssertionError("Unexpected RPC: " + self.path)
            self.respond(200, json.dumps(response).encode())
        except (AssertionError, KeyError, ValueError) as error:
            self.respond(400, json.dumps({"error": str(error)}).encode())


tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
tls.load_cert_chain("/certificates/cert.pem", "/certificates/key.pem")
secure = ThreadingHTTPServer(("0.0.0.0", 8443), Handler)
secure.socket = tls.wrap_socket(secure.socket, server_side=True)
threading.Thread(target=secure.serve_forever, daemon=True).start()
ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
