# vibe-security-check

A security audit skill for apps built with AI — covering **the app you ship** and **the pipeline
that built it**.

Free, offline, no account. Works with Claude Code, Cursor, Windsurf, Copilot, and with any model
including local open-source ones. See [INSTALL.md](INSTALL.md).

## Why

An app built with AI usually has decent code and an open perimeter. The model writes the login
function correctly and leaves the database key in the frontend bundle; it writes the parameterized
query and publishes the bucket. Reviewing the diff finds none of that, because none of it is in the
diff — it lives in `.env`, in the Supabase dashboard, in the bucket policy, in git history.

And when an agent writes the code, the repository becomes an input channel and the agent becomes the
one executing. That is the only surface here where the target can be **you**, on your machine,
before anything is deployed.

## Two skills

The same generated code, examined from two sides. They are kept separate because the findings have
different consequences and different readers, and because a hardcoded hex colour and a hardcoded API
key look alike and are not the same finding.

| Skill | Answers | Read it when |
| --- | --- | --- |
| [`vibe-security-check`](skills/vibe-security-check/SKILL.md) | can someone else read the data? | before publishing, launching, handing off or taking over |
| [`vibe-lint`](skills/vibe-lint/SKILL.md) | can an engineer take this over? | before a prototype becomes a sprint estimate |

A prototype heading for production usually needs both, in that order — a component nobody can
maintain is where a fixed check quietly comes back. `vibe-lint` was
[its own repository](https://github.com/marvinrez/vibe-lint) and now lives here.

## What is in the box

**A skill that dispatches instead of dumping.** A short `SKILL.md` routes to thirteen domain
references loaded only when they apply — secrets, client code, identity, authorization, data stores,
input and output, payments, mobile, cost, model features, operations, the agent pipeline, and the
generator that wrote it. Nothing loads what an app does not have.

**Tool-aware routing.** [`references/generators.md`](skills/vibe-security-check/references/generators.md)
maps every major generator to where its perimeter usually breaks, in three families that fail in
different ways: builders (Lovable, Bolt.new, v0, Replit, Figma Make, Base44, Tempo) inherit platform
defaults tuned for the screen working first time; editors (Cursor, Windsurf, Copilot) fail by
subtraction or by propagating one bad pattern; agents that run commands (Claude Code, Codex, Gemini
CLI, Devin) add the repository as an input channel. One question to whoever hands you the app
decides what to open first.

**Four scripts that produce evidence**, not opinion. Each exits non-zero on a finding, so they drop
into CI unchanged.

| Script | Answers |
| --- | --- |
| `anon-key-probe.sh` | can an anonymous client read or write the database? |
| `bundle-secrets.sh` | did any secret get inlined into the shipped frontend? |
| `history-secrets.sh` | is there a secret anywhere in git history? |
| `exposed-paths.sh` | is `.git`, `.env` or a debug surface served in production? |

**Thirteen Semgrep rules** for the mistakes specific to AI-generated code: the service-role key that
bypasses every rule, the model and token limit taken from the client, the charge amount posted by
the browser, the webhook signature verified against a parsed body, mass assignment straight from the
request, and a taint rule for a model's response reaching a query, a shell command, raw HTML or
`eval` without being parsed into a shape the app defined. Paired fixtures pin the behaviour, and CI enforces it per rule: every rule in the file must
fire on a vulnerable fixture, and none may fire on a safe one. A rule added without a fixture fails
the build.

**Tests that run the scripts.** `scripts/tests/run.sh` executes all four against local stand-in
hosts and fixtures, and checks the three answers that matter: it finds what is there, it stays quiet
on what is clean, and an unreachable host reports as incomplete rather than as a pass.

```bash
semgrep --config skills/vibe-security-check/rules/vibe-security.yaml .
```

Semgrep's default ignore list skips directories named `tests/`, so pointing it at `rules/tests/`
returns nothing and looks like the rules are broken. Pass the fixture files individually, the way
CI does.

**A prevention layer.** [`RULES.md`](RULES.md) copies into a project as `AGENTS.md` or `CLAUDE.md` so
flaws are less likely to be written in the first place. It is not a control, and it says so.

**A portable prompt.** [`PROMPT.md`](skills/vibe-security-check/PROMPT.md) is self-contained for
tools with no skill system, and for local models.

## Method

Two disciplines separate an audit from a scan, and both are in
[`references/method.md`](skills/vibe-security-check/references/method.md).

**Executable proof.** Every High or Critical finding needs the command that demonstrates it, run,
with its output — and the same command after the fix, showing it stopped working. Without that pair
you have a claim.

**Data across a trust boundary.** List what the attacker controls, list where it is used unchecked,
connect the two. Pattern tools do not do this step, which is why a clean scan is not a secure system.

Findings are ranked by who can exploit them today, not grouped by theme.

## What this is not

Not a replacement for a diff-scoped review of a branch, and not a replacement for dependency or
secret scanning. It tells you which free tools to use and — more usefully — what each one
structurally cannot catch.

## Origin

`vibe-security-check` merges three publicly circulating checklists, deduplicates them, and fills the
gaps. Every line is written for this project; nothing is copied from any source. Attribution and the
gap analysis are in [`SOURCES.md`](skills/vibe-security-check/SOURCES.md).

`vibe-lint` started as a separate repository after a `.map()` called on an object took down a demo.
It arrives here unchanged in substance, with its two reference files moved under `references/` and
its boundary with the security skill written down in both directions.

Both by [Marcos Rezende](https://marcosrezende.com), written with Claude.

## Licence

MIT.
