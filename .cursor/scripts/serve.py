#!/usr/bin/env python3
"""Static file server for the CoreActive web bundle.

Mirrors the production hosting behaviour defined in ``web.config``:
  * SPA fallback -- any request that does not map to an existing file or
    directory is rewritten (not redirected) to ``/index.html`` so client-side
    routes such as ``/login``, ``/app`` and ``/reset-password`` work on refresh.
  * Correct ``.wasm`` MIME type for the CanvasKit runtime.

No third-party dependencies are required; only the Python standard library.
"""
from __future__ import annotations

import http.server
import os
import posixpath
import socketserver
from urllib.parse import unquote, urlsplit

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))
ROOT = os.environ.get(
    "WEB_ROOT",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")),
)


class SpaRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".json": "application/json",
    }

    def translate_path(self, path: str) -> str:
        requested = super().translate_path(path)
        if os.path.isdir(requested) or os.path.isfile(requested):
            return requested

        # Only fall back for GET-style navigation requests, not for asset paths
        # that legitimately have a file extension (those should 404 normally).
        clean = unquote(urlsplit(path).path)
        _, ext = posixpath.splitext(posixpath.basename(clean))
        if not ext:
            return os.path.join(ROOT, "index.html")
        return requested

    def end_headers(self) -> None:
        # Avoid stale bundles during development.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        super().log_message(fmt, *args)


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> None:
    os.chdir(ROOT)
    with ThreadingHTTPServer((HOST, PORT), SpaRequestHandler) as httpd:
        print(f"[serve] CoreActive web serving {ROOT} at http://{HOST}:{PORT}")
        print("[serve] SPA fallback enabled (unknown routes -> /index.html)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[serve] Shutting down.")


if __name__ == "__main__":
    main()
