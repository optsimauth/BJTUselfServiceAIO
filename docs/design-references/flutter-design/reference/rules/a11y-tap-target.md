---
title: Targets at least 48dp (44pt on iOS)
impact: CRITICAL
severity: P0
tags: [a11y, touch]
---

# a11y-tap-target

**Impact: CRITICAL (P0)**

`kMinInteractiveDimension` is 48. Expand hit area if the icon is smaller (padding or `InkResponse`), not the icon.

**Incorrect**

```dart
GestureDetector(onTap: f, child: Icon(Icons.close, size: 20))
```

**Correct**

```dart
IconButton(onPressed: f, icon: const Icon(Icons.close), tooltip: 'Close') // 48dp hit area
```

Source: Material a11y, HIG
