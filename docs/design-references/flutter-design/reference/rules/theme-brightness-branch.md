---
title: Never branch on Brightness in widgets
impact: HIGH
severity: P1
tags: [theme, dark-mode]
---

# theme-brightness-branch

**Impact: HIGH (P1)**

A widget that checks brightness duplicates theme logic and drifts. Define both themes; widgets read roles.

**Incorrect**

```dart
final c = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
```

**Correct**

```dart
final c = Theme.of(context).colorScheme.onSurface;
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
