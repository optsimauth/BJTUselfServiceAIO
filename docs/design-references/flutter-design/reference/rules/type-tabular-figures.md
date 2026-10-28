---
title: Tabular figures for numbers that change or align
impact: MEDIUM
severity: P2
tags: [type, data]
---

# type-tabular-figures

**Impact: MEDIUM (P2)**

Prices, timers, tables jitter with proportional digits. Enable `FontFeature.tabularFigures()`.

**Incorrect**

```dart
Text('\$12.40', style: textTheme.titleMedium)
```

**Correct**

```dart
Text('\$12.40', style: textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))
```

Source: docs.flutter.dev, FontFeature
