# Secrets

The domain with the most leak channels, and the only one where a single failure is already a
compromise — not a risk, an incident.

Check this one first, always. One live leaked key outranks every other finding in the report.

## Where they leak

- **Repository and history.** A committed secret stays in history after it is removed from the file.
  Check the whole history, not the current state: `scripts/history-secrets.sh`.
- **Published `.env`.** Confirm it is in `.gitignore` *and* was never committed
  (`git log --all --oneline -- .env`), and that it is not served over the web
  (`scripts/exposed-paths.sh`).
- **Frontend bundle.** Everything reaching the browser is public, including variables prefixed
  `NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_` or `REACT_APP_`. Look in the build, not the source:
  `scripts/bundle-secrets.sh`.
- **Build and CI logs.** Steps that print the environment leak secrets into a log that is often
  public on an open repository.
- **Embedded database credentials.** Connection strings with user and password in code or in a
  versioned file.
- **Error responses.** A stack trace can carry a slice of configuration — see `operations.md`.

## The service-role key

Managed platforms hand out two keys: a public one meant for the browser, and a service-role key that
**bypasses every access rule**. AI-generated code reaches for the second one when the first hits a
permission error, because that makes the feature work. Grep for it by name (`SERVICE_ROLE`,
`service_role`, `SUPABASE_SERVICE_KEY`, `FIREBASE_ADMIN`) and confirm every hit is server-side only.
One service-role key in a bundle is total database compromise regardless of how good the rules are.

## Rotation

Most checklists stop at "don't leak". What decides the size of the damage is what happens after:

- Is there a procedure to revoke and reissue without taking the app down?
- Do you know every place a given key is configured, so reissuing does not break something silently?
- If a key leaked six months ago, would you know?

If the answer to the first is "we'd figure it out then", that is a finding in its own right.

## When you find one

The recommendation is never just "remove it from the code". It is **revoke first** — treat it as
already compromised, because a public repository is indexed within minutes — and clean up
afterwards. Rewriting git history does not un-leak anything already cloned.
