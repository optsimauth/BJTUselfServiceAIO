---
title: Judge smoothness in profile mode on a real device
impact: HIGH
severity: P1
tags: [perf, verify]
---

# perf-profile-mode

**Impact: HIGH (P1)**

Debug builds and emulators lie. Budget 16ms/frame (8ms at 120Hz). Check DevTools for jank, shader compilation (Impeller precompiles) and raster time.

**Incorrect**

```dart
// 'feels fine' in debug on simulator
```

**Correct**

```sh
flutter run --profile -d <device>
```

Source: docs.flutter.dev/perf/ui-performance
