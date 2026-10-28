---
title: No raw colors in widgets
impact: CRITICAL
severity: P1
tags: [theme, color]
---

# theme-raw-colors

**Impact: CRITICAL (P1)**

Raw colors break dark mode, rebrand and contrast checks. Read from `ColorScheme` or a `ThemeExtension`.

**Incorrect**

```dart
Container(color: Colors.blue.shade50, child: Text('x', style: TextStyle(color: Color(0xFF333333))))
```

**Correct**

```dart
Container(color: cs.primaryContainer, child: Text('x', style: TextStyle(color: cs.onPrimaryContainer)))
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
