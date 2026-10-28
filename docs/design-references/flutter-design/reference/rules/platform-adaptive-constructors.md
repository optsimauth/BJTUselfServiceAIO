---
title: Use .adaptive widgets where idiom matters
impact: MEDIUM
severity: P2
tags: [platform]
---

# platform-adaptive-constructors

**Impact: MEDIUM (P2)**

`Switch.adaptive`, `Slider.adaptive`, `CircularProgressIndicator.adaptive`, `showAdaptiveDialog`, `Checkbox.adaptive` follow the platform with no branching code.

**Incorrect**

```dart
Switch(value: true, onChanged: (_) {})
```

**Correct**

```dart
Switch.adaptive(value: true, onChanged: (_) {})
```

Source: docs.flutter.dev/ui/adaptive-responsive/capabilities
