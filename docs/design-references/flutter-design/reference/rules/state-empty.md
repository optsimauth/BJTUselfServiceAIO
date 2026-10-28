---
title: Empty states invite one action
impact: HIGH
severity: P2
tags: [state]
---

# state-empty

**Impact: HIGH (P2)**

Say what is missing, why, and the single next step. Not a blank screen.

**Incorrect**

```dart
if (items.isEmpty) return const SizedBox();
```

**Correct**

```dart
if (items.isEmpty) return EmptyState(title: 'No habits yet', body: 'Track one thing for a week.', action: FilledButton(onPressed: add, child: const Text('Add a habit')));
```

Source: Nielsen
