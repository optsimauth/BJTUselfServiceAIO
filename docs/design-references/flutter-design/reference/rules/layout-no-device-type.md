---
title: Never check device type for layout
impact: HIGH
severity: P1
tags: [layout, adaptive]
---

# layout-no-device-type

**Impact: HIGH (P1)**

Windows resize, fold, split. Layout depends on available space, not hardware. Do not lock orientation to dodge it.

**Incorrect**

```dart
SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]) // to avoid responsive work
```

**Correct**

```dart
LayoutBuilder(builder: (context, c) => c.maxWidth < 600 ? const Compact() : const Wide())
```

Source: docs.flutter.dev/ui/adaptive-responsive
