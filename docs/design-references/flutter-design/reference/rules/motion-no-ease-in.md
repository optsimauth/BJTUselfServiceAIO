---
title: Never ease-in UI motion
impact: MEDIUM
severity: P2
tags: [motion]
---

# motion-no-ease-in

**Impact: MEDIUM (P2)**

Ease-in starts slow, so the UI feels laggy at the moment the user is watching. Use ease-out for enter/exit.

**Incorrect**

```dart
curve: Curves.easeIn
```

**Correct**

```dart
curve: Curves.easeOutCubic
```

Source: Emil Kowalski animation principles (adapted)
