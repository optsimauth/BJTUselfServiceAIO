---
title: At least 8dp between targets
impact: HIGH
severity: P1
tags: [a11y, touch]
---

# a11y-target-spacing

**Impact: HIGH (P1)**

Adjacent targets closer than 8dp cause mis-taps. Use `Gap(8)` or wrap spacing.

**Incorrect**

```dart
Row(children: [btnA, btnB]) // flush
```

**Correct**

```dart
Row(children: [btnA, const Gap(8), btnB])
```

Source: WCAG 2.2, w3.org/TR/WCAG22 2.5.8
