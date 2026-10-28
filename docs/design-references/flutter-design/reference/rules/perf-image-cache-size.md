---
title: Decode images at display size
impact: HIGH
severity: P2
tags: [perf, images]
---

# perf-image-cache-size

**Impact: HIGH (P2)**

Set `cacheWidth/cacheHeight` (or `ResizeImage`) for thumbnails so a 4000px photo is not decoded for a 80dp avatar.

**Incorrect**

```dart
Image.network(url, width: 80)
```

**Correct**

```dart
Image.network(url, width: 80, cacheWidth: (80 * MediaQuery.devicePixelRatioOf(context)).round())
```

Source: docs.flutter.dev/perf
