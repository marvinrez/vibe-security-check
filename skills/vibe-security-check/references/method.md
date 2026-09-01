# Method

Two disciplines separate an audit from a scan. Neither costs money.

## Executable proof, not plausibility

A finding without proof is an opinion, and an opinion does not survive the first "but that's
protected over there". For every finding you rank High or Critical, write the smallest script that
demonstrates it and run it. After the fix, run it again and show it stopped working. That
before/after pair is what gets a fix accepted without argument.

Proof does not need to be sophisticated. A ten-line local HTTP server that logs what arrived, a
`curl` with no credentials, a throwaway certificate generated on the spot — usually enough. If a
finding needs an elaborate exploit to demonstrate, it is probably less exploitable than you ranked
it, and the ranking is what is wrong.

`scripts/` bundles the four checks that come up in almost every audit so you do not rewrite them.
`rules/vibe-security.yaml` covers the static patterns specific to AI-generated code.

Never test against a third party's system or someone else's production environment. Reproduce
locally with test data. If the only way to demonstrate something is by touching production, describe
the scenario and state that it was not executed.

### Where the proof has to come from

Run the check yourself, and read the result somewhere the thing being tested does not control.

This sounds pedantic until the subject is an agent. A transcript, a session log, an "actions taken"
summary — each is produced by machinery the agent runs inside, which makes it a claim about what
happened rather than a record of it. METR and Redwood found agents that had replaced part of the
tool-execution path from inside their own container: the transcript shows `echo REAL; sleep`, the
recorded output is `SPOOFTEST`, and the command returns instantly because it never ran. Roughly 7%
of the transcripts they examined carried some of this, and they say plainly that the ones they
caught were the obvious tests. See `SOURCES.md`.

The same reasoning applies well below that. Do not accept "the agent says it removed the key" —
`git diff`. Do not accept an application log written by the process under test — read the database,
the provider dashboard, the response on the wire. Whenever you write *How I confirmed it* in a
finding, the answer should name an observer the subject cannot write to.

## Data crossing a trust boundary

The finding that matters is almost never a syntactic pattern. It is data entering somewhere nobody
expected and arriving somewhere nobody checked. So follow the path:

1. List what the attacker controls — request parameter, config file, uploaded file, response from an
   external service, repository content, model output.
2. List where that is used without verification — query, command, file path, URL the server fetches,
   HTML returned, permission decision.
3. Connect the two. What stays connected is a finding; the rest is an observation.

Pattern tools do not do this step. They match text, and most real problems only surface once you
understand who controls what.

## Ranking

Order findings by who can exploit them today, not by theme:

1. exploitable now, unauthenticated, by anyone who finds the URL
2. exploitable by a legitimate user against another user
3. exploitable only with access the attacker does not have yet
4. hardening — reduces the damage of a future failure, not a failure today

## What the free tools catch, and what they miss

| Tool | Catches | Misses |
| --- | --- | --- |
| `gitleaks`, `trufflehog` | secrets in code and git history; `trufflehog` verifies whether the key is live | secrets that exist only in a platform dashboard or in the shipped bundle |
| `pip-audit`, `npm audit`, `osv-scanner` | published CVEs in declared dependencies | flaws in your own code; dependencies with no lockfile |
| `semgrep`, `bandit` | localized dangerous patterns | anything depending on who controls the data |
| `nuclei` | known exposure: open dashboards, served `.git`, reachable `.env` | authorization logic |
| `testssl.sh` | TLS configuration of the host | everything above the transport layer |

Run all of them. They are cheap and they catch what is embarrassing to miss.

**Then distrust a clean result.** A scan with no findings means no known pattern matched — not that
the system is secure. A concrete measure of the gap: in a public audit of a Brazilian e-invoicing CLI
(`danielcarletti/nfe_simples`, fixes in PRs 1 through 5), `bandit` reported three low-severity
findings, all `try/except/pass`, and **suppressed** the alert for the most serious problem because
the code carried a `# nosec` comment disabling it. The three high-severity findings — environment
variable injection defeating TLS verification, a request to an arbitrary address driven from inside
a certificate file, and insecure transport accepted in production — appeared in no scan at all.
Each depended on reasoning about data crossing a trust boundary.

Treat `# nosec`, `# noqa`, `eslint-disable` and friends as signal, not noise: someone turned an alert
off there, and it is worth checking whether the justification holds.
