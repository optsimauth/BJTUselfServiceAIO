---
title: Hide decorative elements from semantics
impact: LOW
severity: P3
tags: [a11y, semantics]
---

# a11y-exclude-decorative

**Impact: LOW (P3)**

Dividers, background art, duplicate icons: `ExcludeSemantics` or `Image(excludeFromSemantics: true)`.

**Incorrect**

```dart
Image.asset('bg.png') // announced as unlabeled image
```

**Correct**

```dart
Image.asset('bg.png', excludeFromSemantics: true)
```

Source: api.flutter.dev
