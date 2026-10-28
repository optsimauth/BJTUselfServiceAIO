---
title: Use meaningful route transitions
impact: MEDIUM
severity: P2
tags: [motion, navigation]
---

# motion-page-transitions

**Impact: MEDIUM (P2)**

Shared axis for sibling navigation, container transform for card-to-detail, fade-through for unrelated tabs (`animations` package). Match platform defaults otherwise; support predictive back on Android.

**Incorrect**

```dart
Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const Detail())); // default for a card-to-detail hero
```

**Correct**

```dart
OpenContainer(closedBuilder: (c, open) => const SizedBox.shrink(), openBuilder: (c, _) => const Detail())
```

Source: pub.dev/packages/animations
