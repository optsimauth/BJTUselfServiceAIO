---
title: Never use color alone for meaning
impact: HIGH
severity: P1
tags: [a11y, color]
---

# a11y-not-color-only

**Impact: HIGH (P1)**

Pair status color with icon or text. Error fields get an icon and message.

**Incorrect**

```dart
Text('Low', style: TextStyle(color: Colors.red))
```

**Correct**

```dart
Row(children: [Icon(Icons.warning_amber, color: cs.error), const Text('Low stock')])
```

Source: WCAG 2.2, w3.org/TR/WCAG22 1.4.1
