---
title: Set deliberate line height
impact: LOW
severity: P3
tags: [type]
---

# type-line-height

**Impact: LOW (P3)**

Body 1.4-1.6, headlines 1.1-1.25. Large display text needs tighter leading. Use `height` on the TextTheme, not per widget.

**Incorrect**

```dart
Text(body, style: TextStyle(height: 2.2))
```

**Correct**

```dart
bodyLarge: base.bodyLarge!.copyWith(height: 1.5)
```

Source: Typographic practice
