# Security rules for AI-assisted development

Copy this into a project so the agent reads it while writing code:

```bash
cp RULES.md /path/to/project/AGENTS.md      # Cursor, Copilot, Codex, Windsurf, Gemini CLI
cp RULES.md /path/to/project/CLAUDE.md      # Claude Code
```

**What this is and is not.** It reduces the rate at which these flaws get written, which is worth
having. It is **not** a control: a rule living in a prompt shares context with whatever the agent
reads, including hostile content in a dependency README, and it is versioned where anyone with a
pull request can change it. For an actual control, see `references/agent-pipeline.md`.

---

## Secrets

Never write a credential into source, into a config file that gets committed, or into a variable
prefixed `NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_` or `REACT_APP_` — those are compiled into the
browser bundle and are public.

Never use a service-role or admin key in code that reaches the client. If a permission error appears,
fix the permission rule; do not switch to the key that bypasses rules.

When a credential is needed client-side by design, restrict it at the provider by origin or bundle
identifier.

## Authorization

Put every permission check on the server. A hidden button is not access control.

Every query that fetches a record by id also filters by the owner, and in a multi-tenant app by the
tenant, taken from the session — never from a parameter the client sends.

Updates use an explicit allowlist of writable fields. Never pass a request body straight into an ORM
update, or the client can set `role`, `user_id` or `credits`.

New routes deny by default.

## Client code

Everything that reaches the browser is public and editable — the bundle, the network calls, the
storage. Never compute an answer there that the server needs to trust.

Hiding a component behind `user.role === "admin"` is an interface decision, not a control. The route
behind it needs its own check, written at the same time.

Never send a record to the client that the screen does not display. Filter in the query, not in
JavaScript after the response — a row that arrives is a row that leaked.

Never put a token, a key, a password or a whole user object in `localStorage` or `sessionStorage`;
any script on the origin can read them. Use an `HttpOnly` cookie for the session.

Client-side validation is for the user. Run the same schema on the server, at the boundary.

## Data stores

When creating a table on a managed platform, enable row-level security and write a policy **per
command** — select, insert, update and delete each need one. A select-only policy leaves writes open.

Buckets are private by default. Serve user files through signed URLs with an expiry.

Do not store personal data the feature does not need.

## Input and output

Validate on the server with a schema, at the boundary. Client-side validation is for user experience.

Use parameterized queries or the ORM's query builder. Never build a query by string concatenation.

Do not use `dangerouslySetInnerHTML`, `v-html` or `innerHTML` with user data. If it is unavoidable,
sanitize with a maintained library.

Validate uploads by content type, cap the size before writing, generate the stored filename
yourself, and serve uploads with `Content-Disposition: attachment` and `nosniff`.

If the server fetches a user-supplied URL, restrict the scheme to http and https and reject private
address ranges.

Name the origins CORS accepts. Never reflect the request's origin, and never combine `*` with
credentials.

## Identity

Delegate authentication to a provider when possible. If passwords are stored locally, hash with
argon2id or bcrypt at a current work factor, and use the library's verify function.

Set `HttpOnly`, `Secure` and `SameSite` on session cookies, give sessions an expiry, and invalidate
them on logout and on password change.

Password reset tokens: cryptographically random, short-lived, single use, never returned in an API
response.

## Money

The price comes from the server's own catalogue, never from the request body.

Fulfil on the verified webhook, never on the browser reaching a success URL. Verify the signature
against the raw body, make the handler idempotent, and check the amount matches the order.

## Metered services

Any route calling a paid service — a model, SMS, email, image generation — is authenticated and rate
limited, per account and per address.

`model`, `max_tokens` and equivalent cost parameters are set on the server. Never accept them from
the client.

## Model features

Treat a model's response as untrusted input. Do not place it into a query, into HTML, into a shell
command, or into a tool call with real effects without the same validation you would apply to
anything a user typed. Parse it into a shape you defined, or map it onto an allowlist of actions —
an instruction in the prompt is not a control, because instructions are what injection overwrites.

Everything that reaches the context window is an input channel, not just the chat box: uploads,
retrieved documents, fetched pages, tool results, earlier turns. In an app with shared documents,
whoever can add one can write into someone else's prompt.

Every tool the model can call runs with the calling user's authority, never the app's. Anything
irreversible — send, refund, delete, publish — needs a confirmation or a cap outside the model's
control.

Never put a credential, an internal URL or a business rule in a system prompt. Assume it is public.

## Errors and logs

Return a generic error to the client; keep the detail in the log. Never log credentials, tokens,
card data or full webhook payloads.

## Dependencies

Commit the lockfile. Before adding an unfamiliar package, confirm it actually exists and belongs to
the project it claims — hallucinated package names get registered by attackers.
