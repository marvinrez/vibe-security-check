# Data stores

## Row Level Security, verified with the anonymous key

Managed platforms expose the database directly to the browser, protected only by per-row rules. On
Supabase the anon role is granted every table in the public schema, so row-level security is the
only gate. That design is fine; what decides it is which tables have RLS on and what their policies
say.

Get the semantics right before reading a single policy, because the usual mistake runs the other
way:

- **RLS on with no policy refuses everything.** Postgres applies default deny: no row is visible and
  nothing can be written, for every role except the table owner and roles that bypass RLS. It is the
  locked state, not the empty one.
- **A command with no policy is refused.** A table with only a `SELECT` policy cannot be written
  through the API at all. Adding an `INSERT`, `UPDATE` or `DELETE` policy *opens* that command; no
  policy ever closes one. "Write a policy per command" is how a read-only table becomes writable.

What actually leaves a table open:

- **RLS off.** The grants apply in full, so anyone holding the public key reads and writes every
  row. A table created with plain SQL starts this way, as in any Postgres.
- **A policy that matches everyone.** `USING (true)`, `WITH CHECK (true)`, or a policy for `public`,
  which is every role. RLS is on in name only.
- **A policy for `authenticated` that checks nothing else.** When anyone can sign up,
  `authenticated` means anyone with an email address. The policy has to compare the row with the
  caller — `(select auth.uid()) = user_id` — not merely require a caller.

Read the policies first. This is the only check that covers update and delete:

```sql
select c.relname as "table", c.relrowsecurity as rls_on,
       p.cmd, p.roles, p.qual as "using", p.with_check
from pg_class c
left join pg_policies p on p.schemaname = 'public' and p.tablename = c.relname
where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
order by 1, 3;
```

`rls_on = false` is open, unless the grant to `anon` and `authenticated` was revoked. A policy whose `using` or `with_check` is `true`, or whose roles include
`public` or `anon` on a write, is open to everyone; one for `authenticated` that never mentions the
owner column is open to anyone who signs up. Supabase's Security Advisor runs the first of these
checks for you.

Then test from outside, which costs two requests per table: with the frontend's public key and no
session, no read may return rows and no insert may succeed.

```bash
scripts/anon-key-probe.sh https://YOURPROJECT.supabase.co <anon-key> profiles orders
```

The probe cannot settle update or delete, because PostgREST answers both with 204 whether a policy
refused them or they matched nothing, and a table with no rows reads the same as a locked one —
that is what the query above is for. It also tests only the anonymous caller. Policies that let one
signed-in user reach another's rows need the two-account test in `authorization.md`.

This is the highest-return check in the whole skill. CVE-2025-48757 (CVSS 9.3, confirmed) found more
than 170 production apps leaking names, emails, financial records and live API keys from exactly
this one cause.

For Firebase, test mode ships rules that allow every read and write until a date thirty days out
(`allow read, write: if request.time < timestamp.date(...)`). Check that they were replaced with
real rules — not extended, and not swapped for `if true` or for `if request.auth != null`, which
lets in anyone who signs in.

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
