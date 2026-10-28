---
title: Harmonize dynamic and custom colors
impact: LOW
severity: P3
tags: [color]
---

# color-dynamic-harmonize

**Impact: LOW (P3)**

With `dynamic_color`, brand tokens must `harmonized()` so they sit with wallpaper-derived schemes, while keeping a fixed fallback.

**Incorrect**

```dart
DynamicColorBuilder(builder: (l, d) => MaterialApp(theme: ThemeData(colorScheme: l!)))
```

**Correct**

```dart
DynamicColorBuilder(builder: (l, d) {
  final scheme = l?.harmonized() ?? fallbackLight;
  return MaterialApp(theme: ThemeData(colorScheme: scheme));
})
```

Source: pub.dev/packages/dynamic_color
