---
title: Choose the scheme variant deliberately
impact: MEDIUM
severity: P2
tags: [color]
---

# color-seed-variant

**Impact: MEDIUM (P2)**

`tonalSpot` is calm default; `vibrant`, `expressive`, `fidelity`, `monochrome` change personality. Pick per VARIANCE dial.

**Incorrect**

```dart
ColorScheme.fromSeed(seedColor: seed) // variant never considered
```

**Correct**

```dart
ColorScheme.fromSeed(seedColor: seed, dynamicSchemeVariant: DynamicSchemeVariant.fidelity)
```

Source: Material 3 spec, m3.material.io
