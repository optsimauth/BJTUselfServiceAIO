---
title: Branch on window size classes, not devices
impact: HIGH
severity: P1
tags: [layout, adaptive]
---

# layout-window-classes

**Impact: HIGH (P1)**

Compact <600, medium 600-840, expanded 840-1200, large 1200-1600, extra-large 1600+. Use `MediaQuery.sizeOf` or `LayoutBuilder`.

**Incorrect**

```dart
if (Platform.isIOS) {
  return const SizedBox.shrink(); // device check; also unavailable on web
}
```

**Correct**

```dart
enum WindowClass { compact, medium, expanded, large }
WindowClass windowClassOf(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  return w < 600 ? WindowClass.compact : w < 840 ? WindowClass.medium : w < 1200 ? WindowClass.expanded : WindowClass.large;
}
```

Source: Material 3 layout, m3.material.io/foundations/layout
