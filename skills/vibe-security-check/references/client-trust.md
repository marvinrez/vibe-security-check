# Client code

Generators are good at frontends, so the frontend is where most of a generated app ends up — and
everything in it belongs to whoever opens the page. Not the parts marked private, not the parts
behind a login screen: all of it. The bundle is downloadable, the network calls are replayable, the
storage is readable, and no line of it is a place to keep a decision.

The failure this file describes has one shape in every variant: **the answer was computed where the
attacker sits.**

## The decisions that keep ending up in the browser

Each of these is generated routinely, because in each case putting it client-side is the shortest
path to a working screen.

- **Who you are.** A role read from a field the client can write, or from a token the client can
  swap. Covered in `authorization.md`; it appears here because the visible symptom is a component,
  not a route.
- **What you may see.** `{user?.role === "admin" && <AdminPanel/>}` is fine as an interface
  decision and worthless as a control. The question is never whether the panel renders — it is
  whether `/api/admin/*` answers when you call it with an ordinary session and no interface at all.
- **What it costs.** `model`, `max_tokens`, quantities, tiers. See `cost.md`.
- **What it costs in money.** The price, the currency, the discount. See `payments.md`.
- **Whether the input is acceptable.** A zod schema running only in the browser validates nothing.
  The same schema has to run on the server, at the boundary — see `input-output.md`.
- **Which record this is.** An id, a `tenant_id` or a `user_id` taken from the request body rather
  than from the session.

## Data the client should never have received

Distinct from the above and easy to miss, because the screen looks correct. The query fetches the
whole table — `select('*')`, no filter, or a filter applied in JavaScript after the response — and
the component renders the three rows that belong to this user. The other rows are already on the
machine. Open the network tab and read the response, not the page.

The same pattern hides in a user object carrying `password_hash`, `stripe_customer_id` or an
internal note field, in a list endpoint returning every column of every row, and in an error
response that includes the record it failed on.

## The render boundary

External data reaching a component without a shape check is mostly a crash, and a crash is an
availability problem rather than a breach — worth fixing, ranked accordingly. Two variants are not
just crashes:

- **The escape hatch.** `dangerouslySetInnerHTML`, `v-html`, `innerHTML` and any templating call
  marked raw or safe. The framework escapes by default; each of these is an explicit opt-out
  carrying data from somewhere. See `input-output.md`.
- **Model output rendered directly.** A generated app that streams a model response into the page
  is rendering text an attacker may have influenced. Treat it as user input, because it is.

## Storage in the browser

`localStorage` and `sessionStorage` are readable by any script running on the origin, which means
one XSS is one token theft. A session cookie with `HttpOnly` is not. Look for
`localStorage.setItem` with a token, a key, a password or a whole user object, and for a "remember
me" that persists a credential rather than a session reference.

Service worker caches and IndexedDB have the same property and get less attention.

## How to check

The UI is a suggestion. Check the route, not the screen.

1. `scripts/bundle-secrets.sh` against the **build**, then against the deployed bundle — the
   platform may inject at deploy time what the local build does not contain.
2. Open the network tab, take one authenticated request, and replay it with `curl`: without the
   session, with another account's session, and with fields the interface never sends.
3. Search the source for the escape hatches and for `localStorage.setItem`, and account for every
   hit.
4. Read one list response in full and ask which fields the screen actually uses.

A finding here is only confirmed once the server has been asked directly. "The button is hidden"
is not evidence, in either direction.
