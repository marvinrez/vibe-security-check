# Payments

Money is the one domain where a flaw pays the attacker directly, so it gets probed first and hardest.
It is also where AI-generated code is most confidently wrong, because the happy path is easy and the
adversarial path is invisible.

## The price never comes from the client

The single most common flaw in generated checkout code: the browser posts `{"amount": 4999}` and the
server charges it.

The server looks up the price from its own catalogue, using an item identifier. Quantity is validated
and bounded. Currency is server-chosen. Discount codes are validated server-side, including whether
this user is eligible and whether the code is still live — a coupon check in the frontend is a
coupon generator.

Test it by replaying a legitimate checkout request with the amount lowered to `1`.

## The webhook is the source of truth, and it must be verified

Fulfilment happens when the payment provider says the payment succeeded — not when the browser
returns to `/success`. A user who never pays can navigate to the success URL.

The webhook itself is a public endpoint on your server, so:

- **Verify the signature** with the provider's library and your signing secret. Without it, anyone
  who learns the URL posts a forged "payment succeeded" and gets fulfilled for free. This is the
  single highest-severity payment finding and it is frequently absent.
- **Verify against the raw request body.** Frameworks that parse JSON before the handler runs break
  signature verification, and the usual "fix" found in generated code is to skip verification. Look
  specifically for a body-parser exemption on the webhook route — its absence is the tell.
- **Check the event is recent** so a captured valid event cannot be replayed a year later.
- **Be idempotent.** Providers retry. Fulfilling twice on the same event id gives away product, or
  double-credits an account. Store the event id and ignore repeats.
- **Confirm the amount and currency** on the event match what you expected for that order, rather
  than trusting that the order was the one paid for.

## Authorization on money routes

Every payment-adjacent route needs the ownership check from `authorization.md`, and they are often
missed because they feel like plumbing:

- Can user B fetch user A's invoice, receipt or payment method by id?
- Can a user cancel, refund or modify a subscription that is not theirs?
- Can a user read the customer identifier of another account and use it?

## Card data

If card numbers ever touch your server, the compliance surface changes completely. The correct
answer for almost every app of this kind is that they never do: the provider's hosted fields or
checkout page take the card, and your server only ever sees a token.

If you find raw card data in a request body, a log, or a database column, that is a Critical finding
regardless of how well it is protected.

## What gets logged

Payment flows log generously during development and the logs survive. Look for card details,
full tokens, webhook payloads and provider secrets in application logs and in error trackers.

## Test keys in production, and production keys in test

Both happen. A test key in production means nothing is actually being charged; a production key in a
test environment means real money moves from a place with weaker controls. Confirm which key each
environment holds, and that the two sets are not in the same file.
