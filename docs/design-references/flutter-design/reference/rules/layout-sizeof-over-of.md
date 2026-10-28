---
title: Use MediaQuery.sizeOf, not MediaQuery.of
impact: MEDIUM
severity: P2
tags: [layout, perf]
---

# layout-sizeof-over-of

**Impact: MEDIUM (P2)**

`MediaQuery.of` rebuilds on every field change (keyboard, padding). `sizeOf`, `paddingOf`, `viewInsetsOf` subscribe to one aspect.

**Incorrect**

```dart
final w = MediaQuery.of(context).size.width;
```

**Correct**

```dart
final w = MediaQuery.sizeOf(context).width;
```

Source: docs.flutter.dev/release
