---
title: Design the offline state
impact: MEDIUM
severity: P2
tags: [state]
---

# state-offline

**Impact: MEDIUM (P2)**

Show cached content with a quiet banner; queue writes; never fail silently.

**Incorrect**

```dart
// request throws, UI shows nothing
```

**Correct**

```dart
if (offline) const MaterialBanner(content: Text('You\'re offline. Showing saved data.'), actions: [SizedBox.shrink()])
```

Source: Offline-first practice
