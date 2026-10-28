---
title: Use platform scroll physics
impact: LOW
severity: P3
tags: [platform]
---

# platform-scroll-physics

**Impact: LOW (P3)**

Bouncing on iOS, clamping/stretch on Android. Do not force one globally; `ScrollConfiguration` handles desktop drag devices.

**Incorrect**

```dart
physics: const BouncingScrollPhysics() // everywhere
```

**Correct**

```dart
// default ScrollPhysics resolves per platform; add AlwaysScrollable only for refresh
```

Source: docs.flutter.dev/ui/adaptive-responsive/capabilities
