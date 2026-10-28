---
title: Const constructors everywhere possible
impact: MEDIUM
severity: P3
tags: [perf]
---

# perf-const

**Impact: MEDIUM (P3)**

`const` widgets are skipped on rebuild. Enable `prefer_const_constructors`.

**Incorrect**

```dart
return Padding(padding: EdgeInsets.all(8), child: Text('x'));
```

**Correct**

```dart
return const Padding(padding: EdgeInsets.all(8), child: Text('x'));
```

Source: docs.flutter.dev/perf/best-practices
