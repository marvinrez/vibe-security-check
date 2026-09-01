# Data stores

## Row Level Security, verified with the anonymous key

Managed platforms expose the database directly to the browser, protected only by per-row rules. That
design is fine; the default state is not.

It is not enough to confirm RLS is "on":

- **On with no policy** protects nothing that matters and is the most common default.
- **On with only a `SELECT` policy** leaves `INSERT`, `UPDATE` and `DELETE` open — a very common
  half-done state, because the developer tested reading and stopped.

Write a policy per command, then run the decisive test, which costs four requests: with the
frontend's public key and no session, every read and every write must fail.

```bash
scripts/anon-key-probe.sh https://YOURPROJECT.supabase.co <anon-key> profiles orders
```

This is the highest-return check in the whole skill. CVE-2025-48757 (CVSS 9.3, confirmed) found more
than 170 production apps leaking names, emails, financial records and live API keys from exactly
this one cause.

For Firebase, the equivalent is security rules that default to `allow read, write: if true` in test
mode — check whether test mode was ever turned off.

## Buckets and object storage

S3, Firebase Storage, Supabase Storage and equivalents: confirm objects are neither listable nor
readable anonymously. Test with `curl` and no credentials, against a known object path and against
the bucket root.

Two failure modes worth separating: a *public bucket* leaks everything at once; a *guessable object
path* in a private bucket leaks one file at a time to anyone who guesses. Signed URLs with an expiry
solve the second.

## Encryption at rest

On for the database and on for the backups. A backup restored from an unencrypted snapshot is the
same data with none of the protections.

## Personal data

Not on any of the popular checklists, and in many jurisdictions it carries legal consequences —
including Brazil's LGPD and the GDPR.

- **What personal data does the app store?** Write the list. It is almost always longer than the
  owner expects, because analytics, logs and error reports accumulate it quietly.
- **For how long?** Data with no retention limit is a breach that grows.
- **Is there a deletion path?** When a person asks to be removed, can you actually do it, including
  from backups and from third-party processors?
- **Was it needed?** Storing what you do not need enlarges a future breach for free. The cheapest
  security control available is not collecting the field.
