# Report, fix plan, verification

Three artefacts, produced in order. What makes a report get used rather than filed is each finding
carrying evidence and each fix carrying a way to tell whether it worked — not the item count.

## 1. The report

```
# Security audit — <app>

## Scope
<what was audited, what was left out and why, the date, which parts are live and which are local>

## Threat model in three lines
<sensitive data · actors · where it lives>

## Findings
<ranked by exploitability, not grouped by theme>

### 1. <title> · <Critical|High|Medium|Low>
**Where:** file:line, or dashboard and path
**How I confirmed it:** the command or step, with its output
**If exploited:** the concrete consequence for this app, in one sentence
**Fix:** what to change, in the smallest slice that resolves it

## Not verified
<items depending on access I did not have — named, not omitted>

## Already correct
<what is well done; it sustains the credibility of the rest and prevents rework>
```

When there is no critical finding, say so plainly instead of promoting a medium item to fill the
top. An honest report saying "the basics hold, three hardening items are missing" is worth more than
an inflated alarm, and it is what makes someone come back next time.

## 2. The fix plan

A report without a plan gets read and postponed. Produce one per finding, or one per cluster of
findings that share a root cause — clustering matters, because five symptoms of one missing
ownership check should be fixed once.

```
# Fix plan — <finding or cluster>

## Root cause
<the one thing that is wrong, not the five places it shows>

## Changes
<file by file, what changes and why>

## Verification goal
<the observable fact that will be true when this is fixed, stated before you start>

## How it gets verified
<the command that proves it — ideally the same one that demonstrated the problem>

## Human verification
<what a person must check by hand, because no script can — see human-checks.md>
```

Writing the verification goal **before** implementing is what keeps a fix honest. "The anonymous key
receives 401 on insert" is a goal. "RLS is configured" is a wish.

## 3. The verification pass

For every finding ranked High or Critical:

1. Run the check that demonstrated the problem. Save the output.
2. Apply the fix.
3. Run the same check again. Save the output.
4. Put both in the report, adjacent.

That before/after pair is the deliverable. Without it you have a claim; with it you have a fact, and
whoever reviews the work does not have to take your word for anything.

If a fix cannot be verified by any command, say so and route it to human verification rather than
marking it done.

## Handing over to a non-technical owner

This audit is frequently requested by someone who built the app with AI and does not write code.
When that is the case, the report needs a layer above it, not a simplified version of it.

Open every finding with the consequence, not the mechanism: "anyone with the address can download
your customer list" communicates; "RLS policy missing on the `customers` table" does not. Keep the
mechanism in the report for whoever will fix it.

Give the fix as a step that can be executed, not as a concept. "Implement server-side authorization"
is not actionable for this reader; a specific policy to paste, or a specific setting to change in a
named dashboard, is.

And be explicit about what they must decide rather than what they must do — whether to delay the
launch, whether to notify users, whether a feature is worth its risk. Those are theirs, and burying
them inside technical prose is how they get missed.
