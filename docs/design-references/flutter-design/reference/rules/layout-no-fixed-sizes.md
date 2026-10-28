---
title: Avoid fixed heights for text containers
impact: HIGH
severity: P1
tags: [layout, a11y]
---

# layout-no-fixed-sizes

**Impact: HIGH (P1)**

Fixed height clips at 2.0x text scale and in longer languages. Use constraints (`minHeight`) and let content size.

**Incorrect**

```dart
SizedBox(height: 48, child: Text(label))
```

**Correct**

```dart
ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Text(label))
```

Source: docs.flutter.dev/ui/adaptive-responsive
