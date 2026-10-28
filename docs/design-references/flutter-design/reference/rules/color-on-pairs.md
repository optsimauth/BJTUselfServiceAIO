---
title: Pair every fill with its on-color
impact: HIGH
severity: P1
tags: [color, a11y]
---

# color-on-pairs

**Impact: HIGH (P1)**

`primary` text goes on `onPrimary`; containers use `onXContainer`. Mixing pairs breaks the contrast guarantee.

**Incorrect**

```dart
Container(color: cs.primary, child: Text('x', style: TextStyle(color: cs.onSurface)))
```

**Correct**

```dart
Container(color: cs.primary, child: Text('x', style: TextStyle(color: cs.onPrimary)))
```

Source: Material 3 spec, m3.material.io
