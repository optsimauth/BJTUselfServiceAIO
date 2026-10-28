---
title: Style components once in ThemeData
impact: HIGH
severity: P2
tags: [theme, components]
---

# theme-component-themes

**Impact: HIGH (P2)**

Set `filledButtonTheme`, `inputDecorationTheme`, `cardTheme`, `appBarTheme`, `navigationBarTheme`, `dialogTheme` once. Per-widget `styleFrom` repeats are a smell.

**Incorrect**

```dart
FilledButton(
  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  onPressed: () {},
  child: const Text('Save'),
)
```

**Correct**

```dart
ThemeData(filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder())))
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
