---
title: Disabled at 0.38 content / 0.12 container
impact: LOW
severity: P3
tags: [a11y, states]
---

# a11y-disabled-opacity

**Impact: LOW (P3)**

M3 uses onSurface at 38% for content, 12% for containers. Do not hide disabled text below 3:1 when it carries info; explain why disabled.

**Incorrect**

```dart
Opacity(opacity: 0.2, child: button)
```

**Correct**

```dart
// Let ButtonStyle resolve disabled from the theme
```

Source: Material 3 states, m3.material.io/foundations/interaction/states
