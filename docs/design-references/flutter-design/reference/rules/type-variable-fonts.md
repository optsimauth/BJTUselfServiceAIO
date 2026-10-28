---
title: Use variable font axes when available
impact: LOW
severity: P3
tags: [type]
---

# type-variable-fonts

**Impact: LOW (P3)**

`FontVariation('wght', 560)` gives exact weights and fewer files. Declare axes in pubspec and test fallbacks.

**Incorrect**

```dart
fontWeight: FontWeight.bold // only 400 and 700 files bundled
```

**Correct**

```dart
TextStyle(fontVariations: const [FontVariation('wght', 560)])
```

Source: api.flutter.dev, FontVariation
