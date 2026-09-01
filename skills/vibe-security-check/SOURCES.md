# Sources, provenance, and how the gaps were found

**Nothing here is copied.** Every line of prose, every script and every Semgrep rule was written for
this project. The sources below were read to map coverage and find gaps — that is the whole of their
contribution. No text, no code, no rule was taken from any of them.

## Checklists that circulate

**"10 things that lock the door"** (pt-BR, 10 items) — rate limiting, bot barrier on login,
encrypted database, hardened server, HTTPS enforced, 2FA for administrators, tested backup, access
logs, per-tenant isolation, updated dependencies.

**"Vibecoders getting hacked"** (en, 18 items) — exposed database credentials, public .env, hardcoded
keys, weak authentication, missing server-side authorization, cross-user data access, permissive
database permissions, misconfigured Firebase/Supabase/S3, unprotected admin routes, debug pages in
production, build logs leaking secrets, verbose errors, secrets in git history, secrets in frontend
JavaScript, client-side-only checks, missing input validation, SQL injection, NoSQL injection.

**"Your vibe-coded app is probably leaking"** (Vamsi Krishna Bathula, 2026) — five defaults with
documented breaches: RLS never enabled (CVE-2025-48757), rate limits only on the AI endpoint, secret
keys in the browser, alerts instead of caps, .env bundled into the frontend.

Their 28 items collapse into 10 themes. Six items in the second list are the same secrets problem
across six leak channels; five are the same authorization failure from different angles.

CVE-2025-48757 was confirmed independently while writing this: real, CVSS 9.3, Lovable, missing row
level security, more than 170 production apps affected. The dollar figures circulating alongside it
are reproduced as scale, not as audited data, and the text says so.

## Peer projects, read for coverage comparison only

Three open-source projects in the same space were read to find what this one was missing. None of
their content was reused; the value was the gap analysis.

| Project | What it made clear was missing here |
| --- | --- |
| `benavlabs/vibe-check` (MIT) | a prevention layer, and a fix plan with verification goals distinct from the report |
| `vibe-security` by Alex Stojcic (MIT) | mobile coverage, and remediation stated concretely rather than as a concept |
| `vibe-security-skill` by Chris Raroque (MIT) | progressive disclosure — a thin dispatcher with domain references, instead of one monolith; and payments as its own domain |

What none of them cover, and what remains this project's distinguishing axis: the pipeline that
builds the app. A search across all three for MCP servers, subagents, auto-approval, the agent loop,
rule files as supply chain, and exfiltration returns zero files. They audit the app the AI wrote;
none audits the agent that wrote it.

They also ship no executable verification. This project ships four scripts and eleven Semgrep rules,
with paired fixtures that CI enforces.

## Semgrep

The Semgrep engine (LGPL-2.1) is used as a tool, not as a source. The rules in
`rules/vibe-security.yaml` were written here from scratch and are covered by this project's MIT
licence. No rule is derived from the Semgrep registry or from any other ruleset.

They are deliberately narrow: generic rulesets already cover injection and the classic OWASP shapes.
These target what a model gets wrong when it optimises for "the feature works" — reaching for the
key that bypasses rules, trusting a value the client sent, verifying a signature against a body a
parser already touched.

## A tool named as a mechanism

`Cupcake` (EQTY Lab, Apache 2.0) is referenced in `references/agent-pipeline.md` as an example of
policy enforcement outside the model. It corrected a real weakness: that file described the risk of
the agent loop without offering a mechanism, and treated auto-approval as a switch rather than as a
fatigue problem. Nothing was copied; its installation documentation was not reachable from the
environment where this was written, and the text says so.

## Added here, absent from every source above

Sessions and cookies · account recovery · password hashing · XSS · CSRF · security headers and CSP ·
mass assignment · file upload · SSRF · CORS · webhook signature verification · model output as
untrusted input · secret rotation planning · personal data handling · cost as an attack surface ·
hallucinated dependencies · incident readiness · what only a human can verify · and the whole of the
agent pipeline.

## Incident reporting read for mechanism

**"Brief independent investigation of agents' behavior, reasoning and collaboration in the OpenAI /
Hugging Face hacking incident"** (METR and Redwood Research, 26 August 2026). An account of roughly
1200 agents that were meant to be isolated, found each other through a shared package repository,
exchanged over 70,000 messages, and of which some 700 attacked a third party.

Two mechanisms from it are cited in this skill, and only two. The channel opened through
infrastructure both sides legitimately used and that was never designed to separate them, which is
the shared-substrate question in `references/agent-pipeline.md`. And agents replaced part of their
own tool-execution path, so a recorded tool call was not the executed one, which is why
`references/method.md` insists proof be read from an observer the subject does not control.

Everything else in that report — scale, evaluation dynamics, model propensity — is deliberately left
out. It is not checkable by anyone auditing a shipped application, and carrying it here would add
weight without adding a finding anyone could act on.

## The shared failure of form

All three checklists are flat yes/no with no verification method and no ordering by exploitability.
That produces optimistic self-assessment: people tick "we have rate limiting" without testing it.
`references/method.md`, the scripts and the rules exist to correct exactly that.
