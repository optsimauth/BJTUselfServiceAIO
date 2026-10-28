---
title: UI components and icons 3:1
impact: HIGH
severity: P1
tags: [a11y, color]
---

# a11y-contrast-ui

**Impact: HIGH (P1)**

Borders of inputs, meaningful icons, focus rings need 3:1 against adjacent colors. Use `outline`, not `outlineVariant`, for input borders.

**Incorrect**

```dart
border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant))
```

**Correct**

```dart
border: OutlineInputBorder(borderSide: BorderSide(color: cs.outline))
```

Source: WCAG 2.2, w3.org/TR/WCAG22 1.4.11
