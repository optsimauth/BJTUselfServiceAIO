---
title: Cap content width on large screens
impact: HIGH
severity: P2
tags: [layout, adaptive]
---

# layout-max-content-width

**Impact: HIGH (P2)**

Text lines and forms stretch badly past ~840dp. Center content in a `ConstrainedBox(maxWidth: 840)` or use a two-pane layout.

**Incorrect**

```dart
ListView(children: const [Text('A line of copy that stretches across a 1800dp window')])
```

**Correct**

```dart
Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 840), child: ListView(children: const [Text('A line of copy')])))
```

Source: Material 3 layout, m3.material.io/foundations/layout
