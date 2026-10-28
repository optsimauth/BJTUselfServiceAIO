---
title: Label every non-text control
impact: CRITICAL
severity: P0
tags: [a11y, semantics]
---

# a11y-semantics-label

**Impact: CRITICAL (P0)**

Icon buttons need `tooltip` or `Semantics(label:)`. Images need `semanticLabel` or are excluded when decorative.

**Incorrect**

```dart
IconButton(onPressed: f, icon: Icon(Icons.share))
```

**Correct**

```dart
IconButton(onPressed: f, tooltip: 'Share', icon: const Icon(Icons.share))
```

Source: api.flutter.dev, Semantics
