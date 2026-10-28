---
title: Logical focus and reading order
impact: MEDIUM
severity: P2
tags: [a11y, focus]
---

# a11y-focus-order

**Impact: MEDIUM (P2)**

Use `FocusTraversalGroup` and `OrdinalSortKey` when visual order differs from tree order. Dialogs trap focus; return it on close.

**Incorrect**

```dart
Stack(children: [secondAction, firstAction]) // reversed reading order
```

**Correct**

```dart
import 'package:flutter/semantics.dart';

Semantics(sortKey: const OrdinalSortKey(0), child: firstAction)
```

Source: WCAG 2.2, w3.org/TR/WCAG22 2.4.3
