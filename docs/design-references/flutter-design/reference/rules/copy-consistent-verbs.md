---
title: One verb per intent
impact: LOW
severity: P3
tags: [copy]
---

# copy-consistent-verbs

**Impact: LOW (P3)**

If the button says 'Publish', the toast says 'Published', and the menu says 'Publish'. Not Post/Share/Send.

**Incorrect**

```dart
FilledButton(onPressed: () {}, child: const Text('Publish'));
// toast: 'Your post was shared'  — a different verb
```

**Correct**

```dart
FilledButton(onPressed: () {}, child: const Text('Publish'));
// toast: 'Published
```

Source: Content design practice
