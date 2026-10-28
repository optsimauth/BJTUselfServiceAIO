---
title: RepaintBoundary around heavy animated parts
impact: LOW
severity: P3
tags: [perf]
---

# perf-repaint-boundary

**Impact: LOW (P3)**

Isolate continuously animating or complex subtrees so the rest is not repainted. Verify in DevTools; do not scatter blindly.

**Incorrect**

```dart
// whole screen repaints each tick of a spinner
```

**Correct**

```dart
RepaintBoundary(child: const HeavyAnimatedChart())
```

Source: docs.flutter.dev/perf
