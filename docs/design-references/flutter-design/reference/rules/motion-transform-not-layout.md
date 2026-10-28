---
title: Animate transform and opacity, not layout
impact: HIGH
severity: P2
tags: [motion, perf]
---

# motion-transform-not-layout

**Impact: HIGH (P2)**

Animating width, height, padding forces layout each frame. Use `Transform`, `SlideTransition`, `FadeTransition`, `ScaleTransition`.

**Incorrect**

```dart
AnimatedContainer(duration: const Duration(milliseconds: 200), width: open ? 300 : 0, child: child) // animates layout
```

**Correct**

```dart
FadeTransition(opacity: anim, child: child)
```

Source: docs.flutter.dev/perf
