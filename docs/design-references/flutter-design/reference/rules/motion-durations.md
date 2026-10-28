---
title: Use a duration scale
impact: HIGH
severity: P2
tags: [motion, tokens]
---

# motion-durations

**Impact: HIGH (P2)**

Press 100-160ms, state change 150-250ms, overlays/routes 200-300ms, large layout 300-500ms. UI stays under 300ms when possible.

**Incorrect**

```dart
AnimatedContainer(duration: const Duration(seconds: 1))
```

**Correct**

```dart
abstract final class Motion {
  static const press = Duration(milliseconds: 120);
  static const state = Duration(milliseconds: 200);
  static const overlay = Duration(milliseconds: 280);
}
```

Source: Material 3 motion, m3.material.io/styles/motion
