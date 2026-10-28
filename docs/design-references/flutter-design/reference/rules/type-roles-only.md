---
title: Use Material type roles
impact: HIGH
severity: P1
tags: [type]
---

# type-roles-only

**Impact: HIGH (P1)**

Display, headline, title, body, label, each large/medium/small. Pick a role by function, then override only color or weight.

**Incorrect**

```dart
Text('Hi', style: TextStyle(fontSize: 17))
```

**Correct**

```dart
Text('Hi', style: textTheme.bodyLarge)
```

Source: Material 3 layout, m3.material.io/foundations/layout
