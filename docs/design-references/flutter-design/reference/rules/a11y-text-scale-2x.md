---
title: Layout survives 2.0x text scale
impact: CRITICAL
severity: P0
tags: [a11y, type]
---

# a11y-text-scale-2x

**Impact: CRITICAL (P0)**

Test with `TextScaler.linear(2.0)`; no clipped or overflowed text. Wrap, scroll or reflow, don't shrink.

**Incorrect**

```dart
SizedBox(height: 56, child: Row(children: [Text(longLabel)]))
```

**Correct**

```dart
ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: Row(children: [Expanded(child: Text(longLabel))]))
```

Source: WCAG 2.2, w3.org/TR/WCAG22 1.4.4
