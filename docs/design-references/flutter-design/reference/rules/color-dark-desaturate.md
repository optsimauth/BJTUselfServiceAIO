---
title: Dark mode uses lighter, desaturated tones
impact: HIGH
severity: P1
tags: [color, dark-mode]
---

# color-dark-desaturate

**Impact: HIGH (P1)**

Do not invert. Dark primaries are tone 80 vs light tone 40. Check contrast in each theme separately.

**Incorrect**

```dart
// dark primary = same saturated hue as light
```

**Correct**

```dart
ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)
```

Source: Material 3 spec, m3.material.io
