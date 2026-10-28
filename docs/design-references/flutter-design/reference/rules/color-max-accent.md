---
title: One accent per screen
impact: HIGH
severity: P2
tags: [color]
---

# color-max-accent

**Impact: HIGH (P2)**

Primary draws the eye to one action. Secondary and tertiary support. Saturation on many elements dilutes hierarchy.

**Incorrect**

```dart
// 3 filled primary buttons, 2 tertiary chips, colored icons everywhere
```

**Correct**

```dart
// 1 FilledButton (primary); rest are tonal/outlined/text
```

Source: Material 3 spec, m3.material.io
