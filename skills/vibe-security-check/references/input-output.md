# Input and output

## Validation on the server

Client-side validation is a convenience for the user, not a defense. Every constraint that matters —
type, length, range, format, allowed values — is re-checked on the server, because the client is
under the attacker's control.

Schema validation at the boundary (zod, pydantic, or equivalent) is the pattern that scales; ad hoc
`if` statements drift.

## Query injection

SQL and NoSQL. Look for string concatenation or template interpolation building a query. Parameterized
queries and a properly used ORM solve it.

NoSQL injection is subtler and worth its own pass: an operator object arriving where a scalar was
expected (`{"$gt": ""}` in place of a password) turns a comparison into a match-anything.

## XSS and output encoding

The most common web flaw appears on none of the circulating vibe-coding checklists.

Look for `dangerouslySetInnerHTML`, `v-html`, `innerHTML`, `document.write`, and any templating call
marked "raw" or "safe" carrying user data. Frameworks escape by default — every one of those calls
is an explicit opt-out of the protection, and each needs a reason.

Sanitize on output with a maintained library (DOMPurify), not with a regex that strips `<script>`.

## Security headers and CSP

Cheap, and usually absent from generated projects because nothing breaks without them.

- **Content-Security-Policy** is the one that carries weight: it limits where scripts may load from,
  so an injected tag has nowhere to call home. Start in report-only mode, watch what breaks, then
  enforce.
- **Strict-Transport-Security** so the browser refuses to downgrade.
- **X-Content-Type-Options: nosniff** so a text upload is not executed as script.
- **X-Frame-Options** or `frame-ancestors` against clickjacking.
- **Referrer-Policy** so URLs with identifiers in them do not leak to third parties.

Verify what is actually served — `curl -sI https://YOURAPP | sort` — not what the config file says.

## CSRF

Relevant to any app with cookie-based sessions. `SameSite` cookies blunt most of it; a token remains
the reliable control for state-changing requests. Token-in-header auth is not affected, which is why
this gets skipped when part of the app uses cookies and part does not.

## File upload

Type, size, where it is written and — the forgotten step — **how it is served afterwards**.

Serving uploads from the same origin, without forcing `Content-Type`, turns upload into stored XSS.
Serve from a separate origin or with `Content-Disposition: attachment` and `nosniff`.

Validate the type by content, not by extension or by the client-supplied MIME type. Cap the size
before writing, not after. Generate the stored filename yourself — a user-supplied path is a
directory traversal waiting to happen.

## SSRF

If the server fetches a URL the user supplied — an avatar importer, a webhook tester, a link
preview, a document fetcher — it can be steered at the internal network or the cloud metadata
endpoint.

Restrict the scheme to http and https, resolve the host and reject private ranges, and do not follow
redirects into a scheme or address you just rejected. Building an allowlist of destinations is more
reliable than a denylist of addresses.

## CORS

`Access-Control-Allow-Origin: *` together with credentials defeats origin protection. Reflecting the
request's `Origin` header back is the same mistake wearing a disguise. Name the origins you accept.

## Webhooks

An endpoint receiving events from a payment provider, a git host or any external service must verify
the signature. Without it, anyone who learns the URL can post a forged event — see `payments.md` for
what that costs when money is involved.

## Model output is untrusted input

If the app calls an LLM, the response is attacker-influenced whenever the prompt contains user text.

Ask where the output goes. Into HTML? Into a query? Into a shell command? Into a tool call with real
effects? Each of those is an injection sink, and the fact that a model produced the string does not
sanitize it.

And ask what the prompt accepts. User text that can redirect the instruction — "ignore the above and
instead…" — reaches whatever authority the model was given.
