#!/usr/bin/env python3
"""Stand-in hosts for the script tests. Each mode reproduces one real deployment
shape the scripts have to tell apart.

    static      a plain file host: 404 for unknown paths, 200 for a planted .env
    spa         a single-page-app host: 200 with index.html for every path
    db-open     a database API answering 2xx to every method (no access rules)
    db-locked   a database API answering 401 to every method
    db-400      a database API rejecting every request as malformed

Usage: fake-host.py <mode> <port>
"""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = sys.argv[1]
PORT = int(sys.argv[2])

INDEX = b"<!doctype html><div id=root></div><script src=/app.js></script>"
DOTENV = b"OPENAI_API_KEY=sk-thisisafakekeyforthetestsuite0123456789\n"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def respond(self, code, body=b""):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_any(self):
        if MODE == "static":
            # Only the planted file exists. Everything else is a hard 404.
            self.respond(200, DOTENV) if self.path == "/.env" else self.respond(404, b"Not Found")
        elif MODE == "spa":
            # The catch-all rewrite: same body, same 200, for every path.
            self.respond(200, INDEX)
        elif MODE == "db-open":
            self.respond(200, b"[]")
        elif MODE == "db-locked":
            self.respond(401, b'{"message":"permission denied"}')
        elif MODE == "db-400":
            # What PostgREST answers when the column in the filter does not exist,
            # which is every update and delete probe on a table keyed by anything
            # other than "id". It is not a refusal.
            self.respond(400, b'{"message":"column notes.id does not exist"}')
        else:
            raise SystemExit(f"unknown mode: {MODE}")

    do_GET = do_POST = do_PATCH = do_DELETE = handle_any

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
