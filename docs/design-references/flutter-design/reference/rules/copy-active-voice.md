---
title: Active voice, user's perspective
impact: LOW
severity: P3
tags: [copy]
---

# copy-active-voice

**Impact: LOW (P3)**

'Save changes', not 'Submit'. 'Manage notifications', not 'Configure webhook settings'.

**Incorrect**

```dart
ElevatedButton(onPressed: () {}, child: const Text('Submit'))
```

**Correct**

```dart
FilledButton(onPressed: () {}, child: const Text('Save changes'))
```

Source: Content design practice
