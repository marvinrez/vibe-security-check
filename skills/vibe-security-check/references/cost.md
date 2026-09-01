# Cost as an attack surface

The attacker does not need to steal anything — making you spend is enough. For a solo builder this
is the most likely catastrophic outcome: no data leaks at all, and the invoice arrives.

## An alert is not a cap

Billing data lags hours behind the damage. A leaked key or a runaway loop finishes spending before
the first email lands. Alerts are for the autopsy; a hard cap is what stops it.

Turn on every provider's cap the day you create the project, not when the app grows:

- Spend limits at the model providers.
- The hosting platform's spend control, with auto-pause rather than notify-only.
- Database and backend platform caps.
- Cloud budget alerts at 50, 75 and 90 percent **paired with an action** that actually takes the
  service down, not an email to an address nobody reads on a Saturday.

Check the current default for each rather than trusting any written source, including this one:
product defaults change, and a stale line here is worse than none.

## Per-user quota, on top of the global cap

They solve different problems. The global cap protects your account from bankruptcy. The per-user
quota stops a single abuser consuming the whole cap and taking the service away from everyone else
— which is a denial-of-service that costs the attacker one account.

## The server owns the cost parameters

On any route proxying to a metered service, the expensive knobs never come from the client:

- `model` — or the attacker swaps the cheap model for the most expensive one.
- `max_tokens` — or they set it to the maximum on every call.
- image size, quality, number of variations, video duration.
- the number of retries.

All of these arrive in the same authenticated request as legitimate traffic, so no permission logic
notices. `rules/vibe-security.yaml` includes a rule for the client-controlled model and token case.

## Every metered route is authenticated and limited

Model calls, SMS, email, image generation, PDF rendering, transcription. Behind login, with a
per-account limit, and with the rate limiting from `operations.md`.

One-time-code delivery deserves specific attention: each SMS is billed, so an unlimited OTP endpoint
is simultaneously an attack door and an open tap.

## Orders of magnitude

To calibrate how seriously to rank a missing cap: a front-page traffic spike has taken an account
from tens to hundreds of dollars in a day; denial-of-service against the same kind of setup has
produced five-figure invoices; and keys exposed in public repositories have generated five-figure
bills within days, because scrapers find them in minutes.

Figures circulating in this space are reported rather than audited — treat them as scale, not as
data.
