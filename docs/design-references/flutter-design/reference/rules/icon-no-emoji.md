---
title: No emoji as icons
impact: HIGH
severity: P2
tags: [icon, slop]
---

# icon-no-emoji

**Impact: HIGH (P2)**

Emoji render differently per platform, ignore theme color and scale badly. Use vector icons.

**Incorrect**

```dart
Text('🏠 Home')
```

**Correct**

```dart
Row(children: [const Icon(Symbols.home), const Gap(8), const Text('Home')])
```

Source: Design review
