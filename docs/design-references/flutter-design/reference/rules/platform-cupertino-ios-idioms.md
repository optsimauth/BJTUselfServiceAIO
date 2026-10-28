---
title: Honor iOS idioms on iOS
impact: MEDIUM
severity: P2
tags: [platform, ios]
---

# platform-cupertino-ios-idioms

**Impact: MEDIUM (P2)**

Large-title navigation, swipe-back, sheets with grabber, 17pt body, SF-like text, tab bar with 2-5 items. Branch by `Theme.of(context).platform`, not `Platform.isIOS` (testable, web-safe).

**Incorrect**

```dart
if (Platform.isIOS) {
  return const SizedBox.shrink(); // crashes on web; use Theme.of(context).platform
}
```

**Correct**

```dart
final isCupertino = Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS;
```

Source: Apple HIG
