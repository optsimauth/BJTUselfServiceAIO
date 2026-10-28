---
title: Merge related text into one node
impact: MEDIUM
severity: P2
tags: [a11y, semantics]
---

# a11y-merge-semantics

**Impact: MEDIUM (P2)**

A row of icon + title + value should be read as one item. Use `MergeSemantics` or `Semantics(container: true, label: ...)`.

**Incorrect**

```dart
Row(children: [const Icon(Icons.directions_walk), const Text('Steps'), const Text('8,200')]) // 3 stops
```

**Correct**

```dart
MergeSemantics(child: Row(children: [const Icon(Icons.directions_walk), const Text('Steps'), const Text('8,200')]))
```

Source: api.flutter.dev
