---
title: Avoid saveLayer triggers on large areas
impact: MEDIUM
severity: P2
tags: [perf]
---

# perf-savelayer

**Impact: MEDIUM (P2)**

`Opacity` over large subtrees, `ShaderMask`, `ClipRRect` with `antiAlias`, and blur are costly. Use `FadeTransition`, `AnimatedOpacity` or paint with alpha color.

**Incorrect**

```dart
Opacity(opacity: v, child: bigTree)
```

**Correct**

```dart
FadeTransition(opacity: anim, child: bigTree)
```

Source: docs.flutter.dev/perf/best-practices
