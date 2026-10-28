---
title: One orchestrated moment per screen
impact: MEDIUM
severity: P2
tags: [motion, slop]
---

# motion-one-moment

**Impact: MEDIUM (P2)**

Fade-slide on every item and hover/press scale on every card read as generated. Spend motion on the single most meaningful transition.

**Incorrect**

```dart
// every card has AnimatedContainer + entrance + hover
```

**Correct**

```dart
// Only the hero image uses a shared-axis transition into detail
```

Source: frontend-design principle, adapted
