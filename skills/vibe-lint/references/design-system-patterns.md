# Design System Patterns - Figma Make Reference

This file covers how to apply the universal engineering rules when working with a specific component library or token system. The principles do not change. The syntax does.

---

## The Core Rule

Never use hardcoded values for anything the design system controls.

```js
// Wrong in any stack
style={{ color: "#6C63FF", padding: "16px", fontSize: "14px" }}

// Right - use whatever token syntax your stack provides
// Examples below per library
```

---

## MUI / Material UI (v5+)

```js
// Tokens via sx prop
<Box sx={{ color: "primary.main", p: 2, typography: "body2" }} />

// Responsive values
<Box sx={{ fontSize: { xs: "sm", md: "md" } }} />

// Styled API for complex overrides
import { styled } from "@mui/material/styles";
const Card = styled(Box)(({ theme }) => ({
  borderRadius: theme.shape.borderRadius,
  "&:hover": { boxShadow: theme.shadows[4] },
}));

// Avoid: makeStyles, withStyles (deprecated in v5)
```

---

## Tailwind CSS

```js
// Use utility classes from the config, not arbitrary values
<div className="text-primary bg-surface p-4 rounded-lg" />

// Avoid arbitrary values unless no token exists
<div className="text-[#6C63FF]" />  // only if #6C63FF is not in the config

// Responsive
<div className="text-sm md:text-base" />

// Conditional classes - use clsx or cn helper
import { cn } from "@/lib/utils";
<div className={cn("base-class", isActive && "active-class")} />
```

---

## Radix UI + CSS Custom Properties

```js
// Tokens as CSS variables
<div style={{ color: "var(--color-primary)", padding: "var(--spacing-4)" }} />

// Or via className with your CSS layer
<div className="text-primary p-4" />
```

---

## shadcn/ui

```js
// Uses Tailwind under the hood - same rules apply
// Variants are defined in the component, not inline
<Button variant="outline" size="sm" />

// Do not override with inline styles
// Extend via className with cn() helper
<Button className={cn("w-full", isLoading && "opacity-50")} />
```

---

## Custom Design System (token-based)

```js
// Map token names to CSS variables in your theme file
const tokens = {
  color: { primary: "var(--color-primary)" },
  spacing: { md: "var(--spacing-md)" },
};

// Use tokens everywhere, never raw values
<Component style={{ color: tokens.color.primary }} />
```

---

## Identifying the Stack in Figma Make Output

When reviewing generated code, look for these signals to identify which library is in use:

| Signal | Library |
|---|---|
| `sx={{ }}` prop | MUI |
| `className="text-* bg-* p-*"` | Tailwind |
| `variant="outline"` on custom components | shadcn or Radix |
| `style={{ color: "var(--*)" }}` | CSS custom properties |
| `theme.spacing()` calls | MUI or custom theme |

Once identified, apply the matching rules above and flag any hardcoded values for replacement with the correct token syntax.
