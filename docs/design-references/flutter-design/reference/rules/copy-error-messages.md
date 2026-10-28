---
title: Error copy: cause plus fix, no blame
impact: HIGH
severity: P2
tags: [copy]
---

# copy-error-messages

**Impact: HIGH (P2)**

Say what failed and what to do. No apologies, no codes alone, no 'Invalid input'.

**Incorrect**

```dart
errorText: 'Invalid input'
```

**Correct**

```dart
errorText: 'Use at least 8 characters, with one number.'
```

Source: Nielsen 9
