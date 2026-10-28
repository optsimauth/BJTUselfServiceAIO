---
title: Spacing from a 4/8 token scale
impact: HIGH
severity: P2
tags: [theme, layout]
---

# theme-spacing-tokens

**Impact: HIGH (P2)**

Use named steps (4, 8, 12, 16, 24, 32, 48), never ad hoc 13 or 17.

**Incorrect**

```dart
padding: const EdgeInsets.all(13)
```

**Correct**

```dart
padding: EdgeInsets.all(context.tokens.space3) // 12
```

Source: Material 3 layout, 4dp baseline
