---
title: Snap everything to a 4/8dp grid
impact: MEDIUM
severity: P2
tags: [layout]
---

# layout-grid-4-8

**Impact: MEDIUM (P2)**

Sizes and gaps are multiples of 4 (8 preferred). Odd values signal guesswork.

**Incorrect**

```dart
SizedBox(height: 13)
```

**Correct**

```dart
SizedBox(height: 12) // via token
```

Source: Material 3 layout, m3.material.io/foundations/layout
