---
title: Use WidgetStateProperty for state styling
impact: MEDIUM
severity: P2
tags: [theme, states]
---

# theme-widget-state-property

**Impact: MEDIUM (P2)**

Hover, focus, pressed, disabled styling goes through `WidgetStateProperty` so every state is designed, not just the resting one.

**Incorrect**

```dart
style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue))
```

**Correct**

```dart
style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((s) =>
  s.contains(WidgetState.disabled) ? cs.onSurface.withValues(alpha: 0.12) : cs.primary))
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
