---
title: Motion must be interruptible
impact: MEDIUM
severity: P2
tags: [motion]
---

# motion-interruptible

**Impact: MEDIUM (P2)**

Reverse from current value, never restart. Use controllers' `forward/reverse` or implicit widgets, which retarget smoothly.

**Incorrect**

```dart
controller.reset(); controller.forward();
```

**Correct**

```dart
isOpen ? controller.forward() : controller.reverse();
```

Source: Emil Kowalski animation principles (adapted)
