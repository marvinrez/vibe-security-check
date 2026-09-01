# What wrote it

Ask which tools built the app before you start, because the tool decides where the hole is. The
flaws are not evenly distributed: a builder that wires a database into the browser on the first
prompt almost always ships with the access rules still open, and an editor that only ever touched
one file at a time fails by taking something out rather than by leaving it exposed.

This does not replace the domain files. It tells you which of them to open first, and it is one
question to whoever hands you the app.

## Builders — prompt in, deployed app out

The perimeter is decided by the platform's defaults, and the defaults optimise for the screen
working on the first try.

| Tool | Where the perimeter usually breaks | Open first |
| --- | --- | --- |
| **Lovable** | A managed database is wired to the browser from the first prompt. The public key in the client is by design; whether row-level security stands behind it is a decision nobody was asked to make. Where a policy blocked a feature, an edge function with the service-role key is the usual escape. | `data-stores.md`, `secrets.md`, `anon-key-probe.sh` |
| **Bolt.new** | Generates both halves in one pass, and the server half is as thin as the UI — routes that assume their only caller is the component that calls them, and environment variables that end up on the client side of the build. | `authorization.md`, `bundle-secrets.sh` |
| **v0** | Next.js conventions applied literally: real keys in `NEXT_PUBLIC_` variables, and server actions and route handlers written as if the only caller were the component that calls them. | `secrets.md`, `authorization.md` |
| **Replit** | The app is reachable while it is being built. The workspace URL is public, a committed `.env` sits next to the code instead of in the secrets pane, and deploys happen before anyone decides what should be private. | `operations.md`, `exposed-paths.sh` |
| **Figma Make** | Design-led output: the screens exist before the data layer does, so keys and access rules get added wherever they first made the screen work rather than where they belong. Check where the data is actually fetched from, not what the components look like. | `client-trust.md`, `data-stores.md` |
| **Base44, Tempo and similar** | Managed backend behind a generated UI, with the platform's own auth. The gap is between what the interface offers and what the API accepts — a table left readable, a role field the client can write. | `authorization.md`, `data-stores.md` |

## Editors and autocomplete

The output is a diff, not an app, so the flaw is usually something removed or something propagated.

| Tool | Where the perimeter usually breaks | Open first |
| --- | --- | --- |
| **Cursor** | Failure by subtraction: a check removed to make a test pass, a filter dropped from a query during a refactor, a key pasted into a config while debugging and never taken out. It also reads the repository, so the rule files and MCP config are part of the surface. | `history-secrets.sh`, `agent-pipeline.md` |
| **Windsurf** | Long sessions drift. A constraint honoured in the first ten edits is quietly not honoured in the last ten, and the inconsistency is invisible in any single diff. Check the same class of route in several places, not one example. | `authorization.md`, `method.md` |
| **GitHub Copilot** | Completes toward the nearest pattern in the file, so one insecure query, one unvalidated handler or one missing ownership filter propagates through everything written after it. Findings here cluster; count them before ranking. | `input-output.md`, `authorization.md` |

## Agents that run commands

Everything above, plus a surface the others do not have: the repository is an input channel and the
agent is the one executing, so the target can be your machine before anything is deployed.

| Tool | Where the perimeter usually breaks | Open first |
| --- | --- | --- |
| **Claude Code, Codex, Gemini CLI** | The agent loop itself — what it reads, what it may run without asking, which MCP servers are configured and what their tool descriptions inject into its context. Auto-approve widens all of it at once. | `agent-pipeline.md` |
| **Devin and other unattended agents** | The same, over long runs with nobody watching, where a single accepted instruction from repository content compounds across many commits before anyone reads one. | `agent-pipeline.md`, `human-checks.md` |

## In-chat generation

Claude Artifacts, ChatGPT canvases and their equivalents produce a component with no server behind
it. Any key it uses is in the client and any login it draws is decoration — which is fine for a
prototype and is not the risk. The risk is the shape surviving: the component gets pasted into a
real app, and the fetch call that had no server to authenticate against still has none.

## What no generator builds unless asked

Independent of the tool. These are absent by default because nothing breaks without them, so nothing
prompts anyone to add them:

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

## Most apps are several of these

Scaffolded in a builder, extended in an editor, deployed from a third place, and touched by an agent
somewhere along the way. Ask about the whole path rather than the last tool. The seam between two of
them is where a check gets written once and lost — the builder's generated policy survives, the
editor's refactor drops the filter that depended on it, and neither tool ever saw both halves.

## The other half

A generator's non-security failure modes — data shapes, component structure, hardcoded design
values, the loading and error states that were never written — are the `vibe-lint` skill in this
repository. They are kept separate on purpose: a hardcoded hex colour and a hardcoded API key look
alike and are not the same finding, and merging the two lists is how the second one stops being
read.
