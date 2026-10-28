---
title: One primary action per screen
impact: HIGH
severity: P1
tags: [layout, hierarchy]
---

# layout-one-primary

**Impact: HIGH (P1)**

Decide the one thing. One FAB or one `FilledButton`; others are tonal, outlined or text. Not every screen needs a FAB and an AppBar action.

**Incorrect**

```dart
// FAB + filled AppBar action + 2 filled buttons
```

**Correct**

```dart
// FilledButton for Save; TextButton for Cancel
```

Source: Material 3 layout, m3.material.io/foundations/layout
