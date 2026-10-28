---
title: Hierarchy by size and weight, 3 levels
impact: MEDIUM
severity: P2
tags: [type]
---

# type-weight-hierarchy

**Impact: MEDIUM (P2)**

Use at most 3 emphasis levels per screen. Headings 600-700, body 400, labels 500.

**Incorrect**

```dart
// every line bold or every line regular
```

**Correct**

```dart
titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
```

Source: Material 3 layout, m3.material.io/foundations/layout
