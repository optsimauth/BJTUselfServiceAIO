---
title: No decorative purple/blue gradients
impact: MEDIUM
severity: P2
tags: [color, slop]
---

# color-no-gradient-slop

**Impact: MEDIUM (P2)**

Gradient hero backgrounds and gradient text are the default AI look. A gradient must carry meaning (depth, data), and use hues from the palette.

**Incorrect**

```dart
LinearGradient(colors: [Colors.purple, Colors.blue])
```

**Correct**

```dart
// Solid surface; tonal step from cs.surfaceContainer to cs.surfaceContainerHigh only if it adds meaning
```

Source: Design review
