---
title: Tint neutrals; avoid pure black and white
impact: MEDIUM
severity: P2
tags: [color]
---

# color-no-pure-bw

**Impact: MEDIUM (P2)**

Pure `#000` and `#FFF` surfaces feel harsh. Use `surface` and `onSurface` roles, tinted toward the brand hue.

**Incorrect**

```dart
scaffoldBackgroundColor: Colors.white
```

**Correct**

```dart
// ColorScheme.surface is already tinted; customise with a tinted value
surface: const Color(0xFFF7F8F6)
```

Source: Material 3 spec, m3.material.io
