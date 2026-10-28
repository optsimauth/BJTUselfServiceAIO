---
title: Bundle fonts for production
impact: MEDIUM
severity: P2
tags: [type, perf]
---

# type-font-bundling

**Impact: MEDIUM (P2)**

`google_fonts` runtime fetching causes first-frame flashes and fails offline. Bundle with pubspec assets for release and disable runtime fetch.

**Incorrect**

```dart
GoogleFonts.inter() // fetched at runtime in release
```

**Correct**

```dart
// pubspec.yaml
// flutter:
//   fonts:
//     - family: Inter
//       fonts:
//         - asset: assets/fonts/Inter.ttf
GoogleFonts.config.allowRuntimeFetching = false;
```

Source: pub.dev/packages/google_fonts
