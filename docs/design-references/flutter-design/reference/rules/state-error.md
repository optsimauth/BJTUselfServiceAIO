---
title: Errors state the cause and the fix
impact: HIGH
severity: P1
tags: [state, copy]
---

# state-error

**Impact: HIGH (P1)**

Plain language, no apology, no codes alone. Offer retry. Keep entered data.

**Incorrect**

```dart
Text('Something went wrong')
```

**Correct**

```dart
ErrorState(message: 'Couldn\'t load your habits. Check your connection.', onRetry: reload)
```

Source: Nielsen 9
