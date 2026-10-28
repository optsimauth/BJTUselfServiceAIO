---
title: Status colors are semantic tokens
impact: HIGH
severity: P2
tags: [color, tokens]
---

# color-semantic-status

**Impact: HIGH (P2)**

Success, warning, info are not in ColorScheme. Add them to a ThemeExtension with container/on pairs and harmonize with the seed.

**Incorrect**

```dart
Icon(Icons.check, color: Colors.green)
```

**Correct**

```dart
Icon(Icons.check, color: context.tokens.success)
```

Source: Material 3 spec, m3.material.io
