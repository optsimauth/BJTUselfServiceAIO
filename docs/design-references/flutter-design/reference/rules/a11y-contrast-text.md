---
title: Text contrast at least 4.5:1 (3:1 large)
impact: CRITICAL
severity: P1
tags: [a11y, color]
---

# a11y-contrast-text

**Impact: CRITICAL (P1)**

Large = 18sp+ or 14sp bold+. Verify in light AND dark with `textContrastGuideline`.

**Incorrect**

```dart
Text('x', style: TextStyle(color: Color(0xFF9E9E9E))) // on white = 2.7:1
```

**Correct**

```dart
Text('x', style: TextStyle(color: cs.onSurfaceVariant))
```

Source: WCAG 2.2, w3.org/TR/WCAG22 1.4.3
