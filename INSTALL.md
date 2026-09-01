# Install

Plain Markdown, POSIX shell and Semgrep YAML. No vendor lock-in, no account, no API key. Works with
hosted models and with local open-source ones.

## Claude Code, or anything that reads SKILL.md

```bash
mkdir -p ~/.claude/skills
cp -r skills/vibe-security-check ~/.claude/skills/
cp -r skills/vibe-lint          ~/.claude/skills/     # optional, the handoff pass
```

Per project instead of globally: copy into `.claude/skills/` at the repository root.

`vibe-security-check` triggers on its own when a conversation turns to app security, deploy, `.env`,
API keys, database rules, MCP servers or agent rule files. To invoke it deliberately: *"audit this
app's security before I ship it"*.

`vibe-lint` triggers on AI-generated frontend code, code review and handoff. To invoke it
deliberately: *"code review this, it came out of v0"*. It answers a different question — see
[Two skills](README.md#two-skills).

## Cursor, Windsurf, Copilot, Codex, Gemini CLI

These read a rules file rather than a skill. Use the prevention layer:

```bash
cp RULES.md /path/to/project/AGENTS.md
```

For an audit rather than prevention, paste `skills/vibe-security-check/PROMPT.md` into the chat and
attach the reference files for the domains that apply.

For the handoff pass, `skills/vibe-lint/SKILL.md` carries a ready-to-paste engineering rules block
under *Universal Prompt* that works in the same tools.

## Lovable, v0, Bolt, Replit, ChatGPT, Gemini, or a local model

Paste `skills/vibe-security-check/PROMPT.md`. It is self-contained. Then paste or attach the
`references/*.md` files for whatever the app actually has — there is no need to load domains that do
not apply, and loading fewer keeps a small context window usable.

For a local model through Ollama or llama.cpp, the same paste works. The scripts and Semgrep rules
run regardless of which model you use, because they do not involve a model at all.

## The tooling on its own

The scripts and rules are useful with no model in the loop:

```bash
skills/vibe-security-check/scripts/history-secrets.sh .
skills/vibe-security-check/scripts/bundle-secrets.sh dist
skills/vibe-security-check/scripts/exposed-paths.sh https://your-app.example
skills/vibe-security-check/scripts/anon-key-probe.sh https://PROJECT.supabase.co ANON_KEY table

semgrep --config skills/vibe-security-check/rules/vibe-security.yaml .
```

Each exits non-zero on a finding, so they drop into any CI unchanged.

Only run `exposed-paths.sh` and `anon-key-probe.sh` against hosts you own or are authorized to test.
