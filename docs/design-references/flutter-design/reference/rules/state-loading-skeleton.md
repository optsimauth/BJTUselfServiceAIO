---
title: Skeleton for waits over ~1s
impact: HIGH
severity: P2
tags: [state]
---

# state-loading-skeleton

**Impact: HIGH (P2)**

Match the final layout so nothing jumps. Spinners only for brief or indeterminate actions inside a button.

**Incorrect**

```dart
Center(child: CircularProgressIndicator()) // for a full list
```

**Correct**

```dart
ListView.builder(itemCount: 6, itemBuilder: (_, __) => const SkeletonTile())
```

Source: Nielsen 1: visibility of status
