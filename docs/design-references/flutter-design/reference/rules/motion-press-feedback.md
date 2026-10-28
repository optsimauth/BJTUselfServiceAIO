---
title: Press feedback within 100ms
impact: HIGH
severity: P1
tags: [motion, touch]
---

# motion-press-feedback

**Impact: HIGH (P1)**

Visible response at once: ripple/state layer, or scale 0.97 over 100-160ms. Never `scale(0)` starts; enter from 0.9-0.97 with opacity.

**Incorrect**

```dart
GestureDetector(onTap: go, child: card) // no feedback
```

**Correct**

```dart
AnimatedScale(scale: pressed ? 0.97 : 1.0, duration: Motion.press, curve: Motion.enter, child: card)
```

Source: Emil Kowalski animation principles (adapted)
