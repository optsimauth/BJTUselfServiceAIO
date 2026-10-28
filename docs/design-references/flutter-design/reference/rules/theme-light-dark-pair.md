---
title: Provide theme and darkTheme together
impact: CRITICAL
severity: P1
tags: [theme, dark-mode]
---

# theme-light-dark-pair

**Impact: CRITICAL (P1)**

Ship both. Build dark from the same seed or authored roles, not by inverting. Set `themeMode: ThemeMode.system` by default.

**Incorrect**

```dart
MaterialApp(theme: lightTheme, home: const SizedBox.shrink())
```

**Correct**

```dart
MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.system, home: const SizedBox.shrink())
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
