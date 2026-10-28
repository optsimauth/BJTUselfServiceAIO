---
title: Builders for long or unknown lists
impact: HIGH
severity: P1
tags: [perf, lists]
---

# perf-listview-builder

**Impact: HIGH (P1)**

`ListView(children: [...])` builds everything. Use `.builder`/slivers for 20+ items; add `itemExtent` or `prototypeItem` if uniform.

**Incorrect**

```dart
ListView(children: items.map(Tile.new).toList())
```

**Correct**

```dart
ListView.builder(itemCount: items.length, itemBuilder: (_, i) => Tile(items[i]))
```

Source: docs.flutter.dev/perf
