# Authorization

Several items in circulating checklists describe the same failure from different angles: **the
decision about who can see what is in the wrong place**.

## The check is server-side

Hiding a button does not protect the route behind it. Any check that runs only in the browser is a
suggestion the client is free to ignore — and the client is under the attacker's control.

Look for permission logic in components, in route guards that only affect rendering, in `if
(user.isAdmin)` around a UI element with nothing equivalent on the server.

## One user cannot reach another user's data

The highest-value check in this file, and it needs **two test accounts**.

Take an object identifier from account A and request it with account B's token. If data comes back,
you found it. Repeat for every route that accepts an id — read, update and delete separately, since
they are often protected inconsistently.

Sequential integer ids make this trivial to exploit at scale: an attacker walks 1, 2, 3. Opaque ids
raise the cost but are not the fix — the fix is the ownership check.

## Per-tenant isolation

In a multi-tenant app, every query that filters by object id must **also** filter by tenant id.
Filtering by object id alone is the same bug as above at larger scale, and it is the one that turns
a single curious customer into a full customer-list breach.

The reliable form is to derive the tenant from the session on the server, never from a parameter the
client sends. A `tenant_id` in the request body is an invitation.

## Roles, if there are roles

- **Defined server-side and stored server-side.** A role that arrives in a JWT the client can swap,
  or in a field the client can write, is not a role.
- **Deny by default.** New routes should be inaccessible until explicitly opened, not open until
  someone remembers to protect them. This is the difference between forgetting a route and having a
  hole.
- **Checked at the data layer, not only at the route.** Route-level checks drift as the app grows;
  a query that filters by owner cannot drift.
- **No privilege escalation path.** Can a user assign themselves a role? Can they invite someone at
  a level above their own? Can a deactivated account still act?

## Admin routes

Test by hitting `/admin`, `/dashboard`, `/internal`, `/api/admin/*` authenticated as an ordinary
user, and again with no session at all. "Nobody knows the URL" is not access control.

## Mass assignment

Absent from the popular lists and endemic in AI-generated CRUD: the client sends `{"role":"admin"}`
or `{"user_id": 1}` or `{"credits": 999999}` in an update, and the ORM accepts it because the field
exists on the model.

Test by sending a field the interface never offers. The fix is an explicit allowlist of writable
fields per endpoint — not a denylist, which fails the moment someone adds a column.
