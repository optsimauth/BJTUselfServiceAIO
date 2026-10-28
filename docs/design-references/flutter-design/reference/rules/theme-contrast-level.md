---
title: Offer contrast levels for accessibility
impact: LOW
severity: P3
tags: [theme, a11y]
---

# theme-contrast-level

**Impact: LOW (P3)**

`ColorScheme.fromSeed(contrastLevel:)` gives medium (0.5) and high (1.0) schemes. Wire `MediaQuery.highContrastOf` to them.

**Incorrect**

```dart
theme: ThemeData(colorScheme: scheme) // one contrast only
```

**Correct**

```dart
final hc = MediaQuery.highContrastOf(context);
final highContrastTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seed, contrastLevel: hc ? 1.0 : 0.0),
);
```

Source: Material 3 spec, m3.material.io
