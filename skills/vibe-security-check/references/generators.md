# What wrote it

Ask which tool generated the app before you start, because the tool decides where the hole is. The
flaws are not evenly distributed: a tool with no backend cannot leak a service-role key from a
server it does not have, and a tool that wires a database into the browser on the first prompt
almost always ships with the access rules still open.

This does not replace the domain files. It tells you which of them to open first, and it is worth
one question to the person handing you the app.

## By generator

| What wrote it | Where the perimeter usually breaks | Open first |
| --- | --- | --- |
| **Lovable, Bolt.new** | A managed database is wired to the browser on the first prompt. The public key in the client is by design; whether row-level security stands behind it is a separate decision nobody made. | `data-stores.md`, `anon-key-probe.sh` |
| **v0, and Next.js output generally** | `NEXT_PUBLIC_` variables holding real keys, and server actions or route handlers generated without an authorization check because the caller was a trusted-looking component. | `secrets.md`, `authorization.md` |
| **Replit** | The app is reachable while it is being built. Preview URLs are public, `.env` sits next to the code, and "it is just a prototype" describes intent, not reachability. | `operations.md`, `exposed-paths.sh` |
| **Figma Make, Claude Artifacts, Tempo** | No backend, so any key in use is in the client and any login is decoration. The risk is not the prototype — it is the prototype being extended into a product with the same shape. | `client-trust.md`, `secrets.md` |
| **Cursor, Windsurf, Copilot** | Inline edits. The flaw is usually a subtraction: a check removed to make something pass, a key pasted into a config while debugging and left there, a filter dropped from a query during a refactor. | `client-trust.md`, git history via `history-secrets.sh` |
| **Claude Code, Codex, Gemini CLI, Devin** | The agent reads the repository and runs commands, so the loop itself is a surface and the target can be the machine it runs on. | `agent-pipeline.md` |

Most real apps are two or three of these in sequence — scaffolded in one, extended in an editor,
deployed from a third. Ask about the whole path, not just the last tool. The seam between two tools
is where a check gets written once and lost.

## What no generator builds unless asked

Independent of the tool. These are absent by default because nothing breaks without them, so
nothing prompts anyone to add them:

- Rate limiting on anything, including the routes that cost money (`cost.md`).
- A row-level security policy **per command** — a select policy with insert, update and delete left
  open is the common half-finished state (`data-stores.md`).
- Webhook signature verification against the raw body (`payments.md`).
- A named CORS origin list, rather than a reflected origin (`input-output.md`).
- Security headers and a CSP (`input-output.md`).
- Any answer to "what happens after a key leaks" — rotation, and knowing where a key is configured
  (`secrets.md`).

Treat their absence as expected rather than surprising, and rank them by what this particular app
exposes, not by the fact that they are missing.

## The other half

A generator's non-security failure modes — data shapes, component structure, hardcoded design
values, missing loading and error states — are the `vibe-lint` skill in this repository. They are
kept separate on purpose: a hardcoded hex colour and a hardcoded API key look alike and are not the
same finding, and merging the two lists is how the second one stops being read.
