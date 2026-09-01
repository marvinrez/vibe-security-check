# Operations

Everything that is true about the running system rather than about the code.

## Production exposure

- **Debug mode off.** Development panels, GraphQL introspection, framework admin screens, verbose
  logging endpoints.
- **Generic error to the user, detail in the log.** A stack trace on screen hands over directory
  structure, versions, and sometimes a slice of configuration.
- **Nothing served that should not be.** Run `scripts/exposed-paths.sh` against the deployed host:
  `.git`, `.env`, backup files, `.DS_Store`, directory listings.

## Rate limiting and abuse

- **On every sensitive route**, not only the expensive one. Login, signup, password recovery,
  one-time-code delivery, search, and anything that writes.
- **Keyed by IP *and* by account.** IP alone does not stop a distributed attack; account alone does
  not stop spraying across many accounts.
- **Shared across instances.** A counter in process memory means each replica counts separately and
  the limit is decorative at any real scale. Use shared storage.
- **A bot barrier** on login and public forms — one that does not punish legitimate users with a
  puzzle.

## Transport and host

- **HTTPS enforced**, HTTP redirected, HSTS set. Without it the customer's password travels in the
  clear.
- **Closed host surface.** Only necessary ports open; administrative access by key rather than
  password; database with no public IP where that can be avoided.

## Recovery and detection

- **A backup restored at least once.** A backup never tested is not a backup, it is hope. The
  verification is to restore into a separate environment and confirm the data arrived.
- **Access logs and logs of sensitive events** — login, password change, permission change,
  deletion, payment. Without them an intrusion goes unnoticed and cannot be reconstructed
  afterwards.
- **Someone or something looks.** A log nobody reads and that triggers no alert serves the autopsy,
  not the defence.
- **And the agent's trail.** If an agent writes code here, what *it* executed is a separate record
  and equally necessary. See `agent-pipeline.md`.

## Dependency chain

- **A committed lockfile.** Without a lock, "up to date" means nothing: every install resolves a
  different tree.
- **Automated scanning on every change** (`pip-audit`, `npm audit`, `osv-scanner`, Dependabot). An
  already-published vulnerability is the easiest door of all, because the attacker has nothing to
  discover.
- **Third-party frontend scripts.** A tag loaded from a CDN executes with the same authority as your
  code. Pin the version and use subresource integrity.
- **Watch for hallucinated packages.** AI-generated code sometimes imports a package that does not
  exist; attackers register those names. Confirm every unfamiliar dependency actually belongs to the
  project it claims.

## Incident readiness

Cheap to write down now, expensive to improvise later:

- Who is called, and how, when something happens on a weekend.
- Which credentials get rotated first, and where each one is configured (`secrets.md`).
- How to take the service down or disable a feature without a deploy.
- What you would tell affected users, and what the law where you operate requires you to tell them
  and by when.
