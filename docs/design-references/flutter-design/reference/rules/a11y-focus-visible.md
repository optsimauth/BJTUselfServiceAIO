---
title: Visible keyboard focus
impact: HIGH
severity: P1
tags: [a11y, focus]
---

# a11y-focus-visible

**Impact: HIGH (P1)**

Do not remove focus indication. Style via `focusColor`, `WidgetState.focused` and ring in the theme. Required for web/desktop/Switch Control.

**Incorrect**

```dart
focusColor: Colors.transparent, highlightColor: Colors.transparent
```

**Correct**

```dart
FilledButton.styleFrom(side: WidgetStateBorderSide.resolveWith((s) => s.contains(WidgetState.focused) ? BorderSide(color: cs.primary, width: 3) : null))
```

Source: WCAG 2.2, w3.org/TR/WCAG22 2.4.7
