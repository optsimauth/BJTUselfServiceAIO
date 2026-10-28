---
title: Dialogs match the platform and name the action
impact: MEDIUM
severity: P2
tags: [platform, copy]
---

# platform-dialogs

**Impact: MEDIUM (P2)**

`showAdaptiveDialog` + `AlertDialog.adaptive`. Buttons are verbs ('Delete', 'Keep'), destructive styled as such, never OK/Cancel for destructive.

**Incorrect**

```dart
AlertDialog(title: const Text('Are you sure?'), actions: [TextButton(onPressed: () {}, child: const Text('OK'))])
```

**Correct**

```dart
AlertDialog.adaptive(title: const Text('Delete habit?'), actions: [TextButton(onPressed: no, child: const Text('Keep')), TextButton(onPressed: yes, child: Text('Delete', style: TextStyle(color: cs.error)))])
```

Source: Apple HIG, M3
