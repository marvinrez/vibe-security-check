# What only a person can check

An agent reads code and runs commands. Some of what decides whether an app is safe is neither.
Separating these out matters because a report that silently omits them reads as more complete than
it is — and because these are usually the cheapest items on the list.

Mark each one in the report as verified by a person, or as outstanding. Never mark one as passing
because the code looked right.

## Needs two real accounts

The highest-value check in the whole skill, and no static analysis substitutes for it.

Create two accounts. From account B, try to read, update and delete objects belonging to account A —
by id, on every route that accepts one. In a multi-tenant app, do the same across tenants.

An agent can write the requests; a person has to be willing to create the accounts and accept that
the answer might be embarrassing.

## Needs the provider dashboard

Code cannot see these, and inferring them from configuration files is guessing:

- Are spend caps actually on, with the amounts you think, and does the action pause the service or
  only send an email?
- Are database rules published, or sitting in a draft?
- Is the storage bucket public, per the console rather than per the code?
- Which key does each environment actually hold — test or live?
- Is two-factor authentication on for the accounts that own all of this? Including the domain
  registrar and the email account that can reset everything else.

## Needs a restore

A backup nobody restored is not a backup. Restore into a separate environment and confirm the data
arrived and the app runs against it. This takes an afternoon once and is the difference between an
incident and a catastrophe.

## Needs a decision, not a check

These are the owner's calls. Put them in the report as questions, not as findings:

- Is the personal data being collected worth the obligation it creates?
- Does the launch wait for the fixes, or ship with a known risk accepted deliberately?
- Who gets called at 2am, and do they know that?
- If customer data leaked tomorrow, what would you tell people, and what does the law where you
  operate require you to tell them and by when?

## Needs judgement about the business

A permission model can be technically correct and wrong for the business — an admin role that every
support agent holds, a feature that lets any user export the entire catalogue, a discount that works
as designed and bankrupts the margin. Nothing detects these except someone who knows what the app is
for.

## Needs a second pair of eyes on the agent's work

If an agent wrote the code, someone should read the diff before it ships — specifically looking for
credentials inlined to make a test pass, permissive rules added to make a feature work, and changes
to rule files. See `agent-pipeline.md`.

That review is a person's job precisely because the agent under review cannot be the one certifying
it.
