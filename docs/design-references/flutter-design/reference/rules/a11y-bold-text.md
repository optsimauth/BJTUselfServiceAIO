---
title: Respect Bold Text and high contrast settings
impact: LOW
severity: P3
tags: [a11y]
---

# a11y-bold-text

**Impact: LOW (P3)**

`MediaQuery.boldTextOf` and `highContrastOf` should adjust weights and contrast level.

**Incorrect**

```dart
// ignores accessibility settings
```

**Correct**

```dart
final bold = MediaQuery.boldTextOf(context);
final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
```

Source: api.flutter.dev
