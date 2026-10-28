---
title: Radius is a scale with a rule
impact: MEDIUM
severity: P2
tags: [theme, shape]
---

# theme-radius-tokens

**Impact: MEDIUM (P2)**

One radius on every surface reads as a template. Define a scale (e.g. 4/8/16/28/full) and say which role uses which: controls, surfaces, sheets, avatars.

**Incorrect**

```dart
borderRadius: BorderRadius.circular(12) // on everything
```

**Correct**

```dart
// controls: full; cards: 16; sheets: 28 top; images: 8
borderRadius: BorderRadius.circular(context.tokens.radiusSurface)
```

Source: Material 3 spec, m3.material.io
