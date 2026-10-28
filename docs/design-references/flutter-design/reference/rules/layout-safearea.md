---
title: Respect insets
impact: CRITICAL
severity: P1
tags: [layout, safe-area]
---

# layout-safearea

**Impact: CRITICAL (P1)**

Notches, home indicators, status bars, cutouts. Use `SafeArea` or `MediaQuery.paddingOf`, and for scrollables pad the sliver.

**Incorrect**

```dart
Column(children: [Text('Top')]) // under the notch
```

**Correct**

```dart
SafeArea(child: Column(children: [Text('Top')]))
```

Source: docs.flutter.dev/ui/adaptive-responsive
