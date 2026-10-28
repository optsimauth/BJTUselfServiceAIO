---
title: Keep rebuilds local
impact: MEDIUM
severity: P2
tags: [perf]
---

# perf-rebuild-scope

**Impact: MEDIUM (P2)**

Call `setState`/`watch` as low in the tree as possible; split widgets; use `select`/`ValueListenableBuilder`.

**Incorrect**

```dart
var counter = 0;
setState(() => counter++); // rebuilds the whole State
```

**Correct**

```dart
ValueListenableBuilder(valueListenable: _count, builder: (_, v, __) => Text('$v'))
```

Source: docs.flutter.dev/perf/best-practices
