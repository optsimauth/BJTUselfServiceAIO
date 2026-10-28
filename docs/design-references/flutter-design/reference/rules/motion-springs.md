---
title: Springs for gestures and playful moments
impact: LOW
severity: P3
tags: [motion, spring]
---

# motion-springs

**Impact: LOW (P3)**

Use `SpringDescription` with damping ratio 0.8-1.0 (bounce 0.1-0.3 max). Springs keep velocity when interrupted. Linear/curve for fixed-time UI.

**Incorrect**

```dart
AnimationController(duration: const Duration(seconds: 2), vsync: context as TickerProvider) // far too slow for a drag release
```

**Correct**

```dart
controller.animateWith(SpringSimulation(const SpringDescription(mass: 1, stiffness: 300, damping: 28), from, to, velocity));
```

Source: Flutter physics, material motor package
