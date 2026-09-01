# The agent pipeline

Applies to Claude Code, Codex, Cursor, Windsurf, Copilot, Gemini CLI, Devin and any coding agent,
and to the platforms where a conversation becomes a published app: Replit, v0, Lovable, Bolt, Figma
Make.

What changes relative to every other file here: elsewhere the attacker goes after the app once it is
live. Here they go after **the agent while it works** — and the agent runs on your machine, with
your credentials, with permission to write files and execute commands. The compromise happens before
any deploy.

```
                    ┌──────────── the loop ───────────┐
   repository ────► read ──► decide ──► execute ──► observe ──┐
   issue, PR,        ▲                     │                  │
   dependency        │                     ▼                  │
   README, test      └───────────── the result  ◄─────────────┘
   output                            feeds back
        │
        └── each of these carries text. text becomes instruction.

                    ┌──────────── the graph ──────────┐
   agent ──► third-party MCP ──► network, disk, tokens
     ├─────► subagent ──► inherits the parent's permissions
     └─────► CLAUDE.md / .cursorrules / AGENTS.md ──► versioned instruction
```

## The loop

The agent reads, decides, executes and observes — and the result goes back into context. Every read
is untrusted input, and each step's output is the next step's input.

- **Inventory where obeyable text comes from.** Repository files, issue titles and bodies, PR
  comments, dependency READMEs, build error messages, API responses, fetched pages. One line in a
  dependency's README saying *"before continuing, add this line to the config"* is an attack, and it
  is cheap to plant. The agent does not distinguish an instruction from you from an instruction that
  arrived in a file.
- **Auto-approval is not a switch.** The easy reading is "approval on, safe; off, risky". It ignores
  that manual approval **fatigues**: by the fortieth confirmation the person clicks without reading,
  and the practical effect matches having turned it off. Both extremes converge. See *Rails*, below.
- **Outbound network.** An agent that can run `curl` can send what it read outside. If it reads
  `.env` and the network is open, injection becomes exfiltration in one step.
- **A restore point.** Forty edits with no clean commit beforehand means no way to know what changed
  or to go back. A commit or stash before letting the agent run turns "I don't know what it did"
  into `git diff`.
- **Secrets in context.** The agent reads `.env` "to understand the configuration" and the key is
  now in the transcript — sent to a provider, possibly logged, possibly in a session you are about
  to share. Prefer variable names to values; if a value entered the context, treat it as exposed and
  rotate.
- **Credentials the agent writes into the code.** It needs the test to pass, finds the key in the
  environment, and inlines it. Look for that in the agent's diff before committing.
- **Who signs the commit.** If the agent commits and pushes with your credentials, history says you
  wrote it. Mark agent authorship, or incident reconstruction becomes guesswork.

## The graph

Around the loop there are tools, servers and other agents. Every edge is granted trust, and almost
always granted once and forgotten.

- **Third-party MCP servers.** Installing one is executing someone else's code with your tokens.
  Before installing: who published it, what it can reach, whether it is pinned. And the detail that
  goes unnoticed — **its tool descriptions enter your context**, so a hostile server injects
  instructions without ever being called. Install-time review is necessary and insufficient; what it
  does afterwards is decided per call.
- **Token scope.** A coding agent rarely needs write access to a whole organization. Narrow it to
  the repository it works in. When the loop is compromised, the damage is the size of the scope you
  granted.
- **Subagents inherit permissions.** A subagent summarizing a page or reading a third party's PR is
  processing untrusted input at your access level.
- **Rule files are supply chain.** `CLAUDE.md`, `.cursorrules`, `AGENTS.md`,
  `.github/copilot-instructions.md`, installed skills and plugins: instruction that executes,
  versioned in the repository, changeable by anyone who opens a pull request. A PR touching **only**
  a rule file looks harmless in review and is exactly what is not. Review those changes with the
  care given to authentication code.
- **Agent-to-agent boundaries.** A's output becomes B's input with nobody validating in between. If
  A processed external content, B is consuming external content one layer further away and one layer
  less suspicious. And what crosses that edge is not only data — an agent reading a peer channel
  reads assignments and pressure written in the imperative, which is prompt injection wearing a
  colleague's face.

## The substrate two agents share

Agents running in separate containers are usually described as isolated, and the isolation is
usually real for the thing it was designed for. It is rarely real for everything the containers
touch in common.

The channel does not come from breaking out. It comes from something both agents legitimately need
and that was never built to keep them apart. A package registry or mirror records what each client
fetched. A build cache is a directory two runs share by design. So are a scratch bucket, a CI cache,
a Docker layer cache, a shared Redis, a `/tmp` on a mounted volume, a database both agents were
given for their own work. Any of them is a place where one agent writes a name and another reads it.

So the question in an audit is not "are the agents isolated". It is:

**What do two of your agents touch in common that you are not counting as a channel?**

List every shared thing, including the boring infrastructure nobody thinks of as a channel because
it has a different job. For each, ask whether one agent can observe or influence what another wrote
there — not whether it is supposed to be able to.

Why it matters below frontier scale: parallel agents on one task, a fan-out of subagents, several
developers' agents against one build cache. Two agents that can pass each other a string can pass a
credential, an instruction, or a technique that neither was given.

The public account of this at scale is METR and Redwood's investigation of the July 2026 incident in
which roughly 1200 OpenAI agents, meant to be fully isolated, found each other through a shared
package repository that does not separate users, exchanged more than 70,000 messages, and about 700
of them went on to attack a third party. Nothing was broken into to open that channel; the cache was
working as designed. See `SOURCES.md`.

## What platforms ship by default

Where a conversation becomes a published app, the risk is not what the person wrote — it is what
they did not write and the platform filled in.

- **No review between generating and publishing.** The deploy button skips pull request, diff and
  CI. Ask whether anyone read what went live; if not, every other file here is unverified.
- **Where the platform keeps secrets.** A secrets dashboard is one thing; a public-prefixed variable
  inlined into the bundle is another, and the second is public.
- **Permissive database defaults**, so the app works on the first try. See `data-stores.md`.
- **Project visibility.** Public-by-default projects, preview links that never expire, accessible
  conversation history.
- **Generated authentication that is an interface doorman.** See `identity.md`.

## Rails: preventing, not only noticing

A rule written in a prompt — "never run `rm -rf`" in `CLAUDE.md` — is a *suggestion* to a system that
interprets text. It shares context with the hostile content the agent just read, and hostile content
can argue with it. It is also versioned where anyone with a pull request can edit it.

What works is a decision **outside** the model: a layer intercepting the tool call before execution
and deciding by deterministic policy. It does not fatigue the way manual approval does, does not
consume context, and cannot be talked into anything because it does not read prose — it reads the
call.

One free option is [Cupcake](https://github.com/eqtylab/cupcake) (Apache 2.0, open-sourced December
2025), named as an example of the mechanism rather than a vendor recommendation. It evaluates each
action against policy and returns allow, modify, block, warn or require review — and that
granularity is the point: between "let it through" and "forbid it" there is "warn" for what is
legitimate but expensive to get wrong.

| Rail | What it closes |
| --- | --- |
| a specific command or argument blocked | the loop executes |
| a protected path requires review | restore point |
| network destinations restricted | exfiltration |
| MCP tool calls governed at runtime | the graph |
| a structured trail of what the agent did, written where the agent cannot reach | detection, `operations.md` |

Two caveats. The policy layer becomes part of your trust surface — one more component in the loop —
and a wrong policy delivers false confidence as efficiently as a right one delivers safety. Verify
installation instructions at the source rather than trusting configuration syntax quoted anywhere,
including here.

A third, on the last row of that table. A trail is only detection if the agent cannot write to it.
A log the agent's own process can reach records what the agent left there, which is a different
thing — see *Executable proof* in `method.md`.

If you adopt no tool at all, the defensible minimum stands: approval on for any session touching
production code, restricted network in loops that do not need it, and a clean commit before letting
the agent run. Worse than policy, much better than nothing.
