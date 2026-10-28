---
title: No tracked ALL CAPS eyebrows or numbering chrome
impact: MEDIUM
severity: P2
tags: [type, slop]
---

# type-no-allcaps-eyebrow

**Impact: MEDIUM (P2)**

Tiny uppercase labels over headings, `01 / 02` markers and `A · B · C` meta strings are template chrome. Number only true sequences.

**Incorrect**

```dart
Text('FEATURES', style: TextStyle(letterSpacing: 2, fontSize: 11))
```

**Correct**

```dart
// Put the information in the heading itself
Text('What you can track', style: textTheme.headlineSmall)
```

Source: Design review
