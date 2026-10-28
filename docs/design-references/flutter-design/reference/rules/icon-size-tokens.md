---
title: Icon sizes are tokens
impact: LOW
severity: P3
tags: [icon, tokens]
---

# icon-size-tokens

**Impact: LOW (P3)**

16, 20, 24 (default), 32. Not 21 or 27. Optical size via `opticalSize` for variable symbols.

**Incorrect**

```dart
Icon(Icons.add, size: 21)
```

**Correct**

```dart
Icon(Icons.add, size: context.tokens.iconM)
```

Source: m3.material.io
