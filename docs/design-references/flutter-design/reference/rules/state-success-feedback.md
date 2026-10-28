---
title: Confirm actions in context
impact: MEDIUM
severity: P3
tags: [state]
---

# state-success-feedback

**Impact: MEDIUM (P3)**

Toast/SnackBar for 3-5s, matching the verb ('Published' after Publish). Prefer in-place state change when possible.

**Incorrect**

```dart
// button does work, nothing changes
```

**Correct**

```dart
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Published'), duration: Duration(seconds: 4)))
```

Source: Nielsen 1
