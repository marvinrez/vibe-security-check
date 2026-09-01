---
name: vibe-security-check
description: >-
  Security audit for apps built with AI, covering two surfaces a diff review cannot see: the app you
  ship (secrets, auth, authorization, data stores, input and output, payments, mobile, cost,
  operations) and the pipeline that built it (the agent loop, MCP servers, subagents, rule files).
  Use it before publishing, launching, handing off or taking over anything generated with Claude
  Code, Codex, Cursor, Replit, v0, Lovable, Bolt, Windsurf, Copilot, Gemini CLI or Devin, and
  whenever the question is "is this secure?", "can I ship this?", "can my app get hacked?", "is
  auto-approve safe?", "should I install this MCP server?", "security audit", "pre-deploy review",
  "vibe coding security", "agent security" or "prompt injection". Also use it when a .env file, an
  API key, a Supabase or Firebase rule, a payment webhook, a CLAUDE.md, .cursorrules or AGENTS.md
  file, or an MCP config shows up in a security-relevant way. For a plain diff review of a branch,
  use a diff-scoped review instead.
license: MIT
metadata:
  version: "2.0"
---

# vibe-security-check

An app built with AI usually has decent code and an open perimeter. The model writes the login
function correctly and leaves the database key in the frontend bundle; it writes the parameterized
query and publishes the bucket. Reviewing the diff finds none of that, because none of it is in the
diff — it lives in `.env`, in the Supabase dashboard, in the bucket policy, in git history.

And when the code is written by an agent that reads your repository and executes commands, the
repository becomes an input channel and the agent becomes the one executing. That is the only
surface here where the target can be **you**, on your machine, before anything is deployed.

## Run it in four moves

**1. Map before you check.** Running a checklist without knowing what the app does produces a
generic report nobody acts on. Establish first:

- What sensitive data lives here? (personal, financial, tax, third-party credentials)
- Who are the actors? (anonymous, signed-in user, admin, external system via webhook)
- Where does it live? (managed database, bucket, local file, third-party service)
- What is already published, and what is not yet?
- Which tool wrote it, and does it still have access? (`references/generators.md` — the generator
  decides where the hole is, and it is one question to whoever hands you the app)

If the app stores nobody's data and has no login, half of this does not apply — say so instead of
padding the report with "N/A".

**2. Read `references/method.md` before the first check.** It carries the two disciplines that
separate an audit from a scan: executable proof for every serious finding, and following data
across a trust boundary. Skipping it produces a list of plausible worries.

**3. Work the domains that apply.** Load only what the app actually has — that is why they are
separate files.

| Load | When |
| --- | --- |
| `references/secrets.md` | always — one live leaked key outranks everything else |
| `references/client-trust.md` | there is a browser or app frontend at all |
| `references/identity.md` | there is a login, a session, or a password |
| `references/authorization.md` | users can see data that is not theirs to see |
| `references/data-stores.md` | Supabase, Firebase, Postgres, S3 or any bucket |
| `references/input-output.md` | it takes user input or renders user content |
| `references/payments.md` | money moves, or a payment provider is wired in |
| `references/mobile.md` | there is an iOS, Android or React Native client |
| `references/cost.md` | it calls a metered service — a model, SMS, email, images |
| `references/operations.md` | it is deployed anywhere at all |
| `references/agent-pipeline.md` | an agent wrote the code, or still has access to the repo |
| `references/generators.md` | you know which tool generated it — read it first, it routes the rest |

Two files are not domains and are always relevant: `references/human-checks.md` lists what no script
can verify — separate those in the report instead of silently omitting them — and
`references/report-format.md` carries the output structure.

**4. Report using `references/report-format.md`.** Three artefacts in order: the report, a fix plan
per root cause with its verification goal written *before* implementing, and a verification pass
that re-runs the check that demonstrated the problem. The before/after pair is the deliverable.

## Tooling

Four scripts under `scripts/` produce evidence instead of opinion. Read them before running; they
are short on purpose. Only run the two that touch a host against systems you own or are authorized
to test.

| Script | Answers |
| --- | --- |
| `anon-key-probe.sh` | can an anonymous client read or write the database? |
| `bundle-secrets.sh` | did any secret get inlined into the shipped frontend? |
| `history-secrets.sh` | is there a secret anywhere in git history? |
| `exposed-paths.sh` | is `.git`, `.env` or a debug surface served in production? |

`rules/vibe-security.yaml` holds Semgrep rules for the patterns generic rulesets miss — the ones
specific to AI-generated code. Run with any Semgrep install, no account needed:

```bash
semgrep --config rules/vibe-security.yaml .
```

Free complements, each with a real blind spot documented in `references/method.md`: `gitleaks` or
`trufflehog` for secrets, `pip-audit`/`npm audit`/`osv-scanner` for known CVEs, `nuclei` for
exposure, `testssl.sh` for transport.

## Two things this skill will not do

**It will not confuse a clean scan with a secure system.** Scanners match known patterns. The
findings that matter usually depend on who controls the data, and pattern matching cannot reason
about that.

**It will not rank by theme.** Findings are ordered by who can exploit them today: unauthenticated
first, then user-against-user, then requires-access-they-don't-have, then hardening.

## Preventing, not only finding

`RULES.md` at the repository root is a prevention layer to copy into a project as `AGENTS.md` or
`CLAUDE.md`. It reduces the rate at which these flaws get written. It is **not** a control — a rule
living in a prompt is negotiable by injected text, and it is versioned where anyone with a pull
request can change it. `references/agent-pipeline.md` explains what an actual control looks like.

## Its sibling

The `vibe-lint` skill in this repository covers the same generated code from the other side —
data shapes, component structure, design tokens, the loading and error states that were never
written. It is a handoff and quality pass, not a security pass, and the two are deliberately not
merged: a hardcoded hex colour and a hardcoded API key look alike and are not the same finding.

Use it when the question is "can an engineer take this over?". Use this skill when the question is
"can someone else read the data?". A prototype heading for production usually needs both, in that
order — a component nobody can maintain is where a fixed check quietly comes back.
