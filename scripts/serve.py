#!/usr/bin/env python3
"""Serve web/ with the headers QEMU-Wasm needs.

SharedArrayBuffer (used by QEMU's threads) is only available on
cross-origin-isolated pages, which requires COOP + COEP.

Usage: scripts/serve.py [port]     (default 8088)
"""
import functools
import http.server
import pathlib
import sys

WEB = pathlib.Path(__file__).resolve().parent.parent / "web"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".wasm": "application/wasm",
        ".elf": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
    handler = functools.partial(Handler, directory=str(WEB))
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Serving {WEB} on http://127.0.0.1:{port}/")
        httpd.serve_forever()
