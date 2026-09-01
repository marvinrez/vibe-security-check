# Animation Patterns - Figma Make Reference

Stack-agnostic animation guidance for Figma Make output. Specific examples use Framer Motion since it is the default in Figma Make, but the principles apply to any animation library.

---

## Core Rule

Only animate properties the GPU handles natively. Everything else causes layout recalculation and drops frames.

```js
// Safe to animate - GPU composited
opacity, transform (scale, rotate, x, y, skew)

// Avoid animating - causes layout reflow
width, height, top, left, margin, padding, border-width
```

---

## Entry Animation

```js
import { motion } from "framer-motion";

// Fade and slide up - default for cards, modals, panels
<motion.div
  initial={{ opacity: 0, y: 16 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.25, ease: "easeOut" }}
>
```

---

## Stagger List

Each item enters with a slight delay after the previous one.

```js
const container = {
  hidden: {},
  show: {
    transition: { staggerChildren: 0.07 }
  }
};

const item = {
  hidden: { opacity: 0, y: 10 },
  show: { opacity: 1, y: 0 }
};

<motion.ul variants={container} initial="hidden" animate="show">
  {items.map(i => (
    <motion.li key={i.id} variants={item}>
      <Card {...i} />
    </motion.li>
  ))}
</motion.ul>
```

---

## Hover and Tap

```js
<motion.div
  whileHover={{ scale: 1.02 }}
  whileTap={{ scale: 0.97 }}
  transition={{ type: "spring", stiffness: 400, damping: 25 }}
>
```

---

## Mount and Unmount (AnimatePresence)

```js
import { AnimatePresence, motion } from "framer-motion";

<AnimatePresence>
  {isVisible && (
    <motion.div
      key="panel"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    />
  )}
</AnimatePresence>
```

Always provide a stable `key` prop inside `AnimatePresence`. Without it, exit animations do not fire.

---

## Layout Animation

Animates position changes automatically when sibling elements reorder.

```js
<motion.div layout layoutId={`card-${item.id}`}>
```

---

## Reduced Motion

Respect the user's system preference. This is an accessibility requirement, not optional.

```js
import { useReducedMotion, motion } from "framer-motion";

function AnimatedCard() {
  const prefersReduced = useReducedMotion();

  return (
    <motion.div
      initial={{ opacity: 0, y: prefersReduced ? 0 : 16 }}
      animate={{ opacity: 1, y: 0 }}
    />
  );
}
```

Or globally via the `MotionConfig` wrapper:

```js
import { MotionConfig } from "framer-motion";

<MotionConfig reducedMotion="user">
  <App />
</MotionConfig>
```

---

## CSS Transitions (no library)

When Framer Motion is not in the stack, use CSS transitions for simple interactions.

```css
.card {
  transition: transform 0.2s ease, opacity 0.2s ease;
}

.card:hover {
  transform: scale(1.02);
}

@media (prefers-reduced-motion: reduce) {
  .card {
    transition: none;
  }
}
```

---

## Common Vibe Coding Signals in Animations

- Animation duration over 500ms on interactive elements (too slow)
- `transition: all 0.3s` (animates everything, including layout properties)
- No exit animation on dismissed modals or drawers
- No reduced motion consideration
- `width` or `height` animated instead of `transform: scaleX()` or `scaleY()`
