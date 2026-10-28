---
title: Destructive actions offer undo or confirm
impact: CRITICAL
severity: P1
tags: [state, safety]
---

# state-destructive-undo

**Impact: CRITICAL (P1)**

Prefer undo (SnackBar action) for reversible deletes; confirm dialog for irreversible ones, with a specific verb button.

**Incorrect**

```dart
onPressed: () => repo.delete(id)
```

**Correct**

```dart
onPressed: () { repo.softDelete(id); messenger.showSnackBar(SnackBar(content: const Text('Deleted'), action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(id)))); }
```

Source: Nielsen 3, 5
