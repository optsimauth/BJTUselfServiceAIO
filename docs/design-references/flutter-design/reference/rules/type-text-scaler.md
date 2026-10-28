---
title: Support user text scaling up to 200%
impact: CRITICAL
severity: P0
tags: [type, a11y]
---

# type-text-scaler

**Impact: CRITICAL (P0)**

Never set `textScaler: TextScaler.noScaling` globally. Clamp only for fixed chrome (`TextScaler.clamp(maxScaleFactor: 1.5)`), and test at 2.0.

**Incorrect**

```dart
MediaQuery(data: mq.copyWith(textScaler: TextScaler.noScaling), child: child)
```

**Correct**

```dart
// Allow scaling; clamp narrowly for tab labels only
MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.5)), child: tabBar)
```

Source: WCAG 1.4.4
