---
title: Specific button labels
impact: MEDIUM
severity: P2
tags: [copy]
---

# copy-specific-labels

**Impact: MEDIUM (P2)**

Say what happens: 'Save API key', 'Delete habit'. Never 'Continue', 'OK', 'Yes' for consequential actions.

**Incorrect**

```dart
TextButton(onPressed: () {}, child: const Text('OK'))
```

**Correct**

```dart
TextButton(onPressed: () {}, child: const Text('Delete habit'))
```

Source: Vercel Web Interface Guidelines
