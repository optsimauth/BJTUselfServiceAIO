---
title: Keep lines to 45-75 characters
impact: MEDIUM
severity: P2
tags: [type, layout]
---

# type-line-length

**Impact: MEDIUM (P2)**

Long lines tire the eye. Constrain reading width (`maxWidth` ~ 560-680dp) on tablets and desktop.

**Incorrect**

```dart
Text(article) // full 1400dp width
```

**Correct**

```dart
ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Text(article))
```

Source: Bringhurst, Elements of Typographic Style
