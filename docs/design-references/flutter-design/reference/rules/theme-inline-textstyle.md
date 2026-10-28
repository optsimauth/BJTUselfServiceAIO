---
title: No inline font size or family in widgets
impact: CRITICAL
severity: P1
tags: [theme, type]
---

# theme-inline-textstyle

**Impact: CRITICAL (P1)**

Inline `fontSize` bypasses the type scale and text scaling decisions. Use a `TextTheme` role, then `copyWith` only color or weight when needed.

**Incorrect**

```dart
Text('Title', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
```

**Correct**

```dart
Text('Title', style: Theme.of(context).textTheme.titleLarge)
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
