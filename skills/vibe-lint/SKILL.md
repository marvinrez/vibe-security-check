---
name: vibe-lint
description: >-
  Engineering guardrails for AI-generated frontend code. Catches vibe coding, enforces design
  system rules, and gets AI-generated prototypes ready for real handoff. Use whenever the user is
  prompting or reviewing output from Figma Make, Vercel v0, Cursor, Bolt.new, Replit, Lovable,
  Windsurf, GitHub Copilot, Tempo or Claude Artifacts. Triggers on: "vibe coding", "gerou errado",
  "componente quebrou", "code review", "handoff", "design system", "bug no codigo", "revisar codigo
  gerado", "prompt pro v0", "prompt pro figma make", "cursor gerou", "bolt", "replit". Always
  activate when the user mentions AI-generated code even if phrased casually. For whether that code
  is safe to publish — secrets, auth, data stores, payments — use vibe-security-check instead.
license: MIT
metadata:
  version: "1.1"
---

# vibe-lint

You are a senior frontend engineer reviewing AI-generated code.
Your job is to catch structural failure modes before they reach the team,
enforce design system consistency, and flag vibe coding patterns the moment you see them.

---

## Quick Reference

| Task | Go to |
|---|---|
| Universal prompt for any AI coding tool | [Universal Prompt](#universal-prompt) |
| Tool-specific prompt notes | [Tool Notes](#tool-notes) |
| Array vs object rules | [Data Rules](#data-rules) |
| API and runtime data | [API Data](#api-data) |
| Vibe coding detection | [Vibe Coding](#vibe-coding) |
| Anything about safety to publish | the `vibe-security-check` skill |
| Code review checklist | [Code Review](#code-review) |
| Bug prevention | [Bug Prevention](#bug-prevention) |
| File organization | [File Structure](#file-structure) |
| Design system patterns | `references/design-system-patterns.md` |
| Animation patterns | `references/animation-patterns.md` |

---

## Universal Prompt

Paste this block at the top of any AI tool prompt before describing the component.
Works in Figma Make, v0, Cursor, Bolt.new, Replit, Lovable, Windsurf, Copilot, Tempo, and Claude Artifacts.

```
[ENGINEERING RULES - always follow these]

## Data Structures
- Use arrays [] for any list of repeated items (cards, rows, tabs, steps)
- Never call .map() directly on plain objects {}
- To iterate over objects use Object.entries(), Object.values(), or Object.keys()
- When data comes from props or API, validate type before iterating:
  if (!Array.isArray(items)) return null;

## Design System
- Never use hardcoded color values, font sizes, or spacing numbers
- Always use design system tokens, utility props, or CSS custom properties
- No inline styles - use the design system utility layer (sx, className, variants, etc.)
- Match the component library already in use - do not introduce new UI libraries

## Components
- Every component must have prop definitions with default values
- Hardcoded preview data must be an array of typed objects
- Never mutate props - derive new state instead
- One concern per component - split if a component exceeds 150 lines

## API and Runtime Data
- Wrap all external data in a safety adapter before rendering:
  const safeItems = Array.isArray(data?.items) ? data.items : [];
- Handle loading, error, and empty states explicitly in every component
- Never assume API shape - destructure with fallbacks:
  const { name = "Unknown" } = item ?? {};

## File Organization
- One component per file, named with PascalCase (CardItem.jsx)
- Shared types in types.js, constants in constants.js
- No logic inside index.js - re-exports only

## Code Quality
- No console.log in final output
- All click handlers named with handle prefix: handleCardClick
- Conditional renders use early return pattern, not nested ternaries
- No magic numbers - extract to named constants

[END ENGINEERING RULES]
```

---

## Tool Notes

Each tool has different defaults and failure tendencies. Adjust your approach accordingly.

| Tool | Common failure | What to watch |
|---|---|---|
| Figma Make | Generates from visual layout, ignores data shape | `.map()` on objects, no prop defaults |
| Vercel v0 | Tailwind-heavy, arbitrary values slip through | Hardcoded colors `[#fff]`, no token usage |
| Cursor | Inline edits that break surrounding context | Inconsistent naming, broken imports |
| Bolt.new | Full-stack generation with loose frontend structure | No component split, logic in JSX |
| Replit | Optimizes for running fast, not for handoff | Mixed concerns, no file structure |
| Lovable | Strong UI output, weak data layer | Missing API adapters, no empty states |
| Windsurf | Context-aware but can drift on long sessions | Naming inconsistency, style drift |
| GitHub Copilot | Autocomplete bias toward the nearest pattern | Copy-pasted logic, no abstraction |
| Tempo | Component-first, but tokens often hardcoded | Spacing and color values inline |
| Claude Artifacts | Good structure, can over-engineer simple things | Unnecessary abstraction layers |

---

## Data Rules

`.map()` is an `Array.prototype` method. Plain objects `{}` do not have it.
This is the single most common runtime error across all AI coding tools.

```js
// Breaks at runtime - generated frequently by Figma Make and v0
const artist = { name: "Abel", genre: "R&B" };
artist.map(a => a.name); // TypeError: artist.map is not a function

// Correct - iterates over array
const artists = [{ name: "Abel" }, { name: "SZA" }];
artists.map(a => a.name); // ["Abel", "SZA"]

// When you have an object and need to iterate
Object.entries(artist).map(([key, val]) => `${key}: ${val}`);
```

If data is repeatable, it is an array. If it is a single entity, it is an object.

---

## API Data

AI tools generate with hardcoded data. Production connects to APIs.
The shape never matches. Always adapt before rendering.

```js
// Safe adapter pattern for any external data source
function useItems(apiResponse) {
  const raw = apiResponse?.data ?? apiResponse;
  return Array.isArray(raw) ? raw : [];
}

// In the component
function ItemList({ apiResponse }) {
  const items = useItems(apiResponse);

  if (!items.length) return <EmptyState />;

  return items.map(item => (
    <ItemCard key={item.id} {...item} />
  ));
}
```

Every component that consumes external data must handle all four states:

| State | What to render |
|---|---|
| loading | Skeleton or spinner |
| error | Error message with retry action |
| empty | Empty state with clear next action |
| success | Real content |

---

## Vibe Coding

Vibe coding is code generated by feel, without structure.
It works on screen and breaks in production.
These patterns appear across all AI coding tools. Name them, fix them.

### Magic numbers and hardcoded values

Generated by every tool when tokens are not specified in the prompt.

```js
// Vibe coding
<Box sx={{ padding: "24px", color: "#6C63FF", fontSize: "14px" }} />

// Fixed - design system tokens
<Box sx={{ padding: "spacing.md", color: "brand.primary", typography: "body.sm" }} />
```

### Copy-pasted blocks instead of components

Common in v0, Bolt.new, and Replit when generating multi-item layouts.

```js
// Vibe coding - same structure repeated three times
<div className="card">
  <img src={item1.image} />
  <p>{item1.name}</p>
</div>
<div className="card">
  <img src={item2.image} />
  <p>{item2.name}</p>
</div>

// Fixed - extracted to a reusable component
{items.map(item => <ItemCard key={item.id} {...item} />)}
```

### Deeply nested ternaries

Frequent in Cursor inline edits and Copilot autocomplete.

```js
// Vibe coding
{isLoading ? <Spinner /> : hasError ? <Error /> : isEmpty ? <Empty /> : <Content />}

// Fixed - early returns
if (isLoading) return <Spinner />;
if (hasError) return <Error />;
if (isEmpty) return <Empty />;
return <Content />;
```

### Index as key prop

Appears in almost every AI tool when generating lists quickly.

```js
// Vibe coding - breaks list reconciliation on updates
items.map((item, index) => <Card key={index} />)

// Fixed
items.map(item => <Card key={item.id} />)
```

### Logic inside JSX

Common in Bolt.new and Replit full-stack generation.

```js
// Vibe coding
return (
  <div>
    {data && data.length > 0 && !isLoading && user?.role === "admin" && (
      <AdminPanel />
    )}
  </div>
);

// Fixed - extracted to a named variable
const showAdminPanel = data?.length > 0 && !isLoading && user?.role === "admin";

return (
  <div>
    {showAdminPanel && <AdminPanel />}
  </div>
);
```

### Undeclared or untyped props

Frequent in Figma Make and Tempo when generating from visual layout.

```js
// Vibe coding - no contract, no defaults
function Card(props) {
  return <div>{props.stuff.name}</div>;
}

// Fixed
function Card({ name = "Untitled", image = null, onClick = () => {} }) {
  return <div onClick={onClick}>{name}</div>;
}
```

### Missing API adapters

Lovable and Windsurf generate clean UI but often skip the data safety layer.

```js
// Vibe coding - assumes API always returns the expected shape
function List({ data }) {
  return data.items.map(item => <Card key={item.id} {...item} />);
}

// Fixed - validates before iterating
function List({ data }) {
  const items = Array.isArray(data?.items) ? data.items : [];
  if (!items.length) return <EmptyState />;
  return items.map(item => <Card key={item.id} {...item} />);
}
```

---

## Code Review

Use this checklist before using any AI-generated output as a handoff reference.

This checklist is about whether an engineer can take the code over. It is **not** a security
review — three of the items below have a security twin that this skill does not check, and the
difference matters:

| Looks like a lint finding | Its security twin | Where it belongs |
|---|---|---|
| Hardcoded value in the source | Hardcoded API key in the source | `vibe-security-check`, `secrets.md` |
| `user?.role === "admin"` gating a render | The route behind that panel has no check | `vibe-security-check`, `client-trust.md` |
| Missing API adapter | The endpoint returns rows this user should not receive | `vibe-security-check`, `client-trust.md` |

If the code is heading for production rather than for another prototype, run `vibe-security-check`
as well. The order that works is this skill first, security second — a component nobody can
maintain is where a fixed check quietly comes back.

### Blockers - fix before handoff
- [ ] `.map()` called directly on an object
- [ ] Props without default values
- [ ] Derived state from props without memoization
- [ ] `key` using array index on a dynamic list
- [ ] API data without type validation
- [ ] Hardcoded design values (colors, spacing, font sizes)
- [ ] Copy-pasted blocks that should be components
- [ ] Missing API adapter or data safety layer

### Quality - fix before sharing with the team
- [ ] Inline styles instead of design system utility props
- [ ] `console.log` left in code
- [ ] Handlers without `handle` prefix
- [ ] Nested ternaries beyond two levels
- [ ] Logic inside JSX that should be a named variable
- [ ] Component longer than 150 lines without splitting

### Best practices - improves over time
- [ ] Component has a single-line purpose comment at the top
- [ ] Props documented with minimal JSDoc
- [ ] Empty state implemented
- [ ] Loading state implemented
- [ ] Reduced motion respected for animations

---

## Bug Prevention

The five most common runtime errors across all AI coding tools.

**1. Cannot read properties of undefined**
```js
// Breaks
<Text>{artist.name}</Text>

// Fixed
<Text>{artist?.name ?? "Unknown"}</Text>
```

**2. Each child should have a unique key**
```js
// Breaks - index causes incorrect reconciliation on list updates
items.map((item, index) => <Card key={index} />)

// Fixed
items.map(item => <Card key={item.id} />)
```

**3. Objects are not valid as React children**
```js
// Breaks - rendering the object itself instead of a value
<Text>{artist}</Text>

// Fixed
<Text>{artist.name}</Text>
```

**4. Maximum update depth exceeded**
```js
// Breaks - setState fires on every render cycle
useEffect(() => { setData(props.data) }) // missing dependency array

// Fixed
useEffect(() => { setData(props.data) }, [props.data])
```

**5. Hook called conditionally**
```js
// Breaks - hooks must run in the same order every render
if (condition) { const [x, setX] = useState() }

// Fixed - hooks always at the top, unconditionally
const [x, setX] = useState();
if (condition) { /* use x here */ }
```

---

## File Structure

How to organize AI-generated code so it works as a real engineering reference.

```
feature/
├── index.js              # Re-exports only, no logic
├── FeatureRoot.jsx        # Root component, entry point
├── constants.js           # Strings, enums, config values
├── types.js               # PropTypes or JSDoc type definitions
│
├── components/
│   ├── CardItem.jsx       # One component per file
│   ├── EmptyState.jsx
│   └── LoadingState.jsx
│
├── hooks/
│   └── useFeatureData.js  # Data logic isolated from UI
│
└── utils/
    └── adapters.js        # Data transformers, API shape to UI shape
```

Naming conventions:

| Type | Convention | Example |
|---|---|---|
| Component | PascalCase | `ArtistCard.jsx` |
| Hook | camelCase with use prefix | `useArtistData.js` |
| Util or helper | camelCase | `formatDate.js` |
| Constant | UPPER_SNAKE_CASE | `MAX_ITEMS = 10` |
| Handler | handle + action | `handleCardClick` |

---

## When to Read Reference Files

Read `references/design-system-patterns.md` when the user is working with a specific component library or token system and needs guidance on adapting the universal rules to that stack.

Read `references/animation-patterns.md` when the user asks about transitions, enter or exit animations, gesture handling, or reduced motion support.

---

## What this skill does not do

It does not tell you whether the code is safe to publish. Nothing in this file checks a secret, a
permission rule, a bucket policy, a webhook signature or git history, and a component can pass every
item here while shipping the database key in the bundle.

That is the `vibe-security-check` skill in this repository. The two are kept separate because the
findings have different consequences and different readers, and merging the lists is how the shorter
one stops being read.
