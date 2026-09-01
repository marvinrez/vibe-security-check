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

## What is in the box

**A skill that dispatches instead of dumping.** A short `SKILL.md` routes to ten domain references
loaded only when they apply — secrets, identity, authorization, data stores, input and output,
payments, mobile, cost, operations, the agent pipeline. Nothing loads what an app does not have.

**Four scripts that produce evidence**, not opinion. Each exits non-zero on a finding, so they drop
into CI unchanged.

| Script | Answers |
| --- | --- |
| `anon-key-probe.sh` | can an anonymous client read or write the database? |
| `bundle-secrets.sh` | did any secret get inlined into the shipped frontend? |
| `history-secrets.sh` | is there a secret anywhere in git history? |
| `exposed-paths.sh` | is `.git`, `.env` or a debug surface served in production? |

**Eleven Semgrep rules** for the mistakes specific to AI-generated code: the service-role key that
bypasses every rule, the model and token limit taken from the client, the charge amount posted by
the browser, the webhook signature verified against a parsed body, mass assignment straight from the
request. Paired fixtures pin the behaviour — `vulnerable.ts` must trigger every rule, `safe.ts` must
trigger none, and CI enforces both.

```bash
semgrep --config skills/vibe-security-check/rules/vibe-security.yaml .
```

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

Merges three publicly circulating checklists, deduplicates them, and fills the gaps. Every line is
written for this project; nothing is copied from any source. Attribution and the gap analysis are in
[`SOURCES.md`](skills/vibe-security-check/SOURCES.md).

## Licence

MIT.
