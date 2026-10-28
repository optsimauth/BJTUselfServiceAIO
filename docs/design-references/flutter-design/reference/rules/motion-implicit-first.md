---
title: Prefer implicit animations
impact: MEDIUM
severity: P2
tags: [motion]
---

# motion-implicit-first

**Impact: MEDIUM (P2)**

`AnimatedOpacity`, `AnimatedSlide`, `TweenAnimationBuilder` before controllers. Controllers only for sequences, loops, gestures.

**Incorrect**

```dart
class _FadeState extends State<StatefulWidget> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // a controller for one fade
}
```

**Correct**

```dart
AnimatedOpacity(opacity: visible ? 1 : 0, duration: Motion.state, child: child)
```

Source: docs.flutter.dev/ui/animations
