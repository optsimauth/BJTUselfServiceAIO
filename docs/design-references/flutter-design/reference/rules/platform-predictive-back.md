---
title: Support predictive back on Android
impact: HIGH
severity: P2
tags: [platform, android]
---

# platform-predictive-back

**Impact: HIGH (P2)**

Use `PopScope` (not `WillPopScope`), enable `android:enableOnBackInvokedCallback`, and `PredictiveBackPageTransitionsBuilder` in the page transitions theme.

**Incorrect**

```dart
// WillPopScope was removed from the SDK. Swallowing back with no handler is the same bug:
PopScope(canPop: false, child: page)
```

**Correct**

```dart
PopScope(canPop: !dirty, onPopInvokedWithResult: (didPop, _) { if (!didPop) confirmDiscard(); }, child: page)
```

Source: docs.flutter.dev/platform-integration/android/predictive-back
