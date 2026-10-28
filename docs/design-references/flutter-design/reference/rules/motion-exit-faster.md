---
title: Exits are faster than enters
impact: MEDIUM
severity: P3
tags: [motion]
---

# motion-exit-faster

**Impact: MEDIUM (P3)**

Exit about 0.6-0.7x of enter. The system responds fast when dismissing.

**Incorrect**

```dart
duration: const Duration(milliseconds: 300), // same duration for enter and exit
```

**Correct**

```dart
transitionDuration: const Duration(milliseconds: 280),
reverseTransitionDuration: const Duration(milliseconds: 180),
```

Source: Material 3 motion, m3.material.io/styles/motion
