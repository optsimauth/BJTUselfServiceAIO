---
title: Vary spacing to express grouping
impact: MEDIUM
severity: P2
tags: [layout]
---

# layout-rhythm

**Impact: MEDIUM (P2)**

Related items closer (8), sections apart (32-48). Uniform padding flattens hierarchy.

**Incorrect**

```dart
Padding(padding: const EdgeInsets.all(16), child: const Text('Block')) // same padding on every block
```

**Correct**

```dart
Column(children: [header, Gap(8), subtitle, Gap(32), section])
```

Source: Gestalt proximity
