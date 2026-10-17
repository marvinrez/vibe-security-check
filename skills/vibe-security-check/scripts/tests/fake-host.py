#!/usr/bin/env python3
"""Stand-in hosts for the script tests. Each mode reproduces one real deployment
shape the scripts have to tell apart.

    static       a plain file host: 404 for unknown paths, 200 for a planted .env
    spa          a single-page-app host: 200 with the same index.html for every path
    nonce        the same, but index.html carries a fresh CSP nonce on every request,
                 and a real .env is planted next to it
    redirect     a host that sends every path elsewhere (apex to www, http to https)
    authwall     a host behind a login wall (preview protection, an access proxy)
    securitytxt  a file host that publishes /.well-known/security.txt and nothing else
    pgrst        a Supabase project API. Each table replays what PostgREST 12.2.3 on
                 Postgres 16 answered to the anon role for that RLS state, recorded
                 against a real database with Supabase's default grants:

                     rls_off     RLS disabled
                     no_policy   RLS enabled, no policy at all
                     using_true  RLS enabled, FOR ALL USING (true) WITH CHECK (true)
                     anon_read   RLS enabled, FOR SELECT TO anon USING (true)
                     no_grant    the anon role has no grant on the table
                     (other)     a table the API does not expose

Usage: fake-host.py <mode> <port>
"""
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = sys.argv[1]
PORT = int(sys.argv[2])

INDEX = b"<!doctype html><div id=root></div><script src=/app.js></script>"
DOTENV = b"OPENAI_API_KEY=sk-thisisafakekeyforthetestsuite0123456789\n"
SECURITY_TXT = b"Contact: mailto:security@example.invalid\nExpires: 2030-01-01T00:00:00Z\n"

RLS_DENIED = b'{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy for table \\"t\\""}'
NO_GRANT = b'{"code":"42501","details":null,"hint":null,"message":"permission denied for table t"}'
NOT_NULL = (b'{"code":"23502","details":"Failing row contains (3, null, null).","hint":null,'
            b'"message":"null value in column \\"note\\" of relation \\"t\\" violates not-null constraint"}')
MISSING = b'{"code":"42P01","details":null,"hint":null,"message":"relation \\"public.t\\" does not exist"}'
ROWS = b'[{"id":1,"user_id":null,"note":"a"}]'

TABLES = {  # table -> {method: (status, body)}; update and delete answer 204 everywhere
    "rls_off":    {"GET": (200, ROWS),    "POST": (400, NOT_NULL)},
    "no_policy":  {"GET": (200, b"[]"),   "POST": (401, RLS_DENIED)},
    "using_true": {"GET": (200, ROWS),    "POST": (201, b"")},
    "anon_read":  {"GET": (200, ROWS),    "POST": (401, RLS_DENIED)},
    "no_grant":   {"GET": (401, NO_GRANT), "POST": (401, NO_GRANT)},
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def respond(self, code, body=b"", headers=()):
        self.send_response(code)
        self.send_header("Content-Type", "application/json" if body[:1] in (b"[", b"{") else "text/plain")
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_any(self):
        # Drain the request body, or the next request on this connection is
        # parsed starting from it.
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        path = self.path.split("?")[0]

        if MODE == "static":
            # Only the planted file exists. Everything else is a hard 404.
            self.respond(200, DOTENV) if path == "/.env" else self.respond(404, b"Not Found")
        elif MODE == "spa":
            # The catch-all rewrite: same body, same 200, for every path.
            self.respond(200, INDEX)
        elif MODE == "nonce":
            if path == "/.env":
                self.respond(200, DOTENV)
            else:
                nonce = os.urandom(8).hex().encode()
                self.respond(200, b'<!doctype html><script nonce="' + nonce + b'" src=/app.js></script>')
        elif MODE == "redirect":
            self.respond(308, b"", [("Location", "https://www.example.invalid" + self.path)])
        elif MODE == "authwall":
            self.respond(401, b"Authentication required")
        elif MODE == "securitytxt":
            if path == "/.well-known/security.txt":
                self.respond(200, SECURITY_TXT)
            else:
                self.respond(404, b"Not Found")
        elif MODE == "pgrst":
            table = path.removeprefix("/rest/v1/")
            if table not in TABLES:
                self.respond(404, MISSING)
            elif self.command in ("PATCH", "DELETE"):
                self.respond(204)
            else:
                self.respond(*TABLES[table][self.command])
        else:
            raise SystemExit(f"unknown mode: {MODE}")

    do_GET = do_POST = do_PATCH = do_DELETE = handle_any

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
