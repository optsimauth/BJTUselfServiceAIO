---
title: Elevate with surface container roles
impact: MEDIUM
severity: P2
tags: [color, elevation]
---

# color-surface-containers

**Impact: MEDIUM (P2)**

M3 expresses depth through `surfaceContainerLow..Highest`, not drop shadows. Pick the role that matches importance.

**Incorrect**

```dart
Card(elevation: 8, shadowColor: Colors.black)
```

**Correct**

```dart
Card(elevation: 0, color: cs.surfaceContainerLow)
```

Source: Material 3 spec, m3.material.io
