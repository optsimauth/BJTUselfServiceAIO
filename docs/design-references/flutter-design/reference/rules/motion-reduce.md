---
title: Honor reduced motion with gentler alternatives
impact: CRITICAL
severity: P1
tags: [motion, a11y]
---

# motion-reduce

**Impact: CRITICAL (P1)**

Check `MediaQuery.disableAnimationsOf(context)`. Keep opacity/color changes, drop travel, scale and parallax. Not a global duration 0.

**Incorrect**

```dart
AnimatedSlide(duration: d, offset: offset, child: child) // runs even when reduce-motion is on
```

**Correct**

```dart
final reduceMotion = MediaQuery.disableAnimationsOf(context);
AnimatedSlide(
  duration: reduceMotion ? Duration.zero : Motion.state,
  offset: reduceMotion ? Offset.zero : offset,
  child: child,
);
```

Source: WCAG 2.3.3
