---
title: Secondary text is tinted, not gray
impact: LOW
severity: P3
tags: [color]
---

# color-tint-neutrals

**Impact: LOW (P3)**

Use `onSurfaceVariant` for secondary text, not `Colors.grey`.

**Incorrect**

```dart
Text('sub', style: TextStyle(color: Colors.grey))
```

**Correct**

```dart
Text('sub', style: TextStyle(color: cs.onSurfaceVariant))
```

Source: Material 3 spec, m3.material.io
