---
title: Body text 14-16sp, never below 12sp
impact: HIGH
severity: P1
tags: [type, a11y]
---

# type-body-size

**Impact: HIGH (P1)**

M3 body is 14-16. Captions can be 12. Below that is unreadable. iOS idiom is 17pt body; honor it in Cupertino flows.

**Incorrect**

```dart
TextStyle(fontSize: 10)
```

**Correct**

```dart
textTheme.bodyMedium // 14sp
```

Source: Material 3 layout, m3.material.io/foundations/layout
