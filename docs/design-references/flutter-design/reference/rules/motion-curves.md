---
title: Use strong custom curves, not built-ins
impact: MEDIUM
severity: P2
tags: [motion]
---

# motion-curves

**Impact: MEDIUM (P2)**

Flutter's `Curves.easeOut` is gentle. Use `Cubic(0.23, 1, 0.32, 1)` for enter, `Curves.easeInOutCubicEmphasized` for on-screen movement, `Cubic(0.32, 0.72, 0, 1)` for drawers.

**Incorrect**

```dart
curve: Curves.linear
```

**Correct**

```dart
abstract final class Enter {
  static const curve = Cubic(0.23, 1, 0.32, 1);
}
```

Source: Emil Kowalski animation principles (adapted)
