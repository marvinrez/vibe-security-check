# Identity

## Authentication exists and is server-side

A login screen that only hides the interface is not authentication. The decisive test is to call the
API directly, bypassing the frontend entirely — with `curl`, with no session, against a route the UI
only shows to signed-in users. If data comes back, the login is decoration.

This is the single highest-return check on a platform-built app, because generated auth is
frequently an interface doorman.

## Password hashing

If the app stores passwords itself rather than delegating to a provider, this is where a breach
turns from bad to catastrophic — leaked hashes that crack in minutes mean every reused password of
every user is now live elsewhere.

- **Use a memory-hard algorithm.** argon2id is the current default; bcrypt and scrypt remain
  acceptable. Not SHA-256, not MD5, not SHA-512 — those are built to be fast, which is exactly the
  wrong property. Speed is the attacker's advantage.
- **Never hand-roll.** No custom salting scheme, no "hash it twice", no pepper invented on the spot.
  Use the library's defaults; they encode the salt and parameters into the stored string for you.
- **Check the work factor.** A library default from years ago may be low now. argon2id with sensible
  memory and iteration costs, bcrypt with a cost that takes visible time on your hardware.
- **Compare in constant time.** Use the library's verify function, never `==` on hashes.

If the app delegates to a provider (Supabase Auth, Clerk, Auth0, Firebase Auth), this whole section
is theirs — confirm the delegation is real and no parallel local password path exists.

## Sessions

- **Cookie flags.** `HttpOnly` so script cannot read it, `Secure` so it never travels in the clear,
  `SameSite` to blunt cross-site submission.
- **An expiry that exists.** A session valid forever is a stolen laptop that never stops paying out.
- **Invalidation on logout and on password change.** The most forgotten one. A session that survives
  a password change means changing the password does not evict the intruder — which is precisely
  what the user was trying to do.
- **Rotation on privilege change.** Issue a new session identifier when someone signs in or gains a
  role, so a token captured before the change does not inherit what came after.

## Account recovery

The "forgot password" flow is authentication's back door, and popular checklists never mention it.
Everything you enforced above is bypassed if this is weak.

- **Token entropy.** Generated with a cryptographic random source, not a timestamp, not a counter,
  not a hash of the email.
- **Short expiry**, measured in minutes to an hour, not days.
- **Single use**, invalidated the moment it is redeemed or a new one is issued.
- **Delivered out of band** and never returned in the API response — a reset token in the JSON body
  is a password reset for anyone who can call the endpoint.
- **Rate limited**, both per account and per address, or the endpoint becomes an email bomb and an
  enumeration oracle at once. See `operations.md`.

## Second factor for administrators

One leaked admin password should not open the whole system. If the app has any notion of an elevated
role, that role needs a second factor — this is the cheapest single reduction in blast radius
available.

## Enumeration

"No account with that email" tells an attacker which addresses to keep trying. Return the same
message and take roughly the same time whether the account exists or not, on login, on signup and on
recovery.
