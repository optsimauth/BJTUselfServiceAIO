---
title: Stagger 30-50ms, never block input
impact: LOW
severity: P3
tags: [motion]
---

# motion-stagger

**Impact: LOW (P3)**

Group entrances with 30-50ms offsets; cap total under ~400ms; interaction stays live during it.

**Incorrect**

```dart
Future.delayed(Duration(milliseconds: i * 200))
```

**Correct**

```dart
Interval(i * 0.06, (i * 0.06 + 0.5).clamp(0, 1).toDouble(), curve: Motion.enter)
```

Source: Emil Kowalski animation principles (adapted)
