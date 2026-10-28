---
title: No work in build()
impact: HIGH
severity: P1
tags: [perf]
---

# perf-no-work-in-build

**Impact: HIGH (P1)**

No sorting, parsing, or future creation in `build`; cache in state or provider.

**Incorrect**

```dart
FutureBuilder<int>(future: api.load(), builder: (_, _) => const SizedBox.shrink()) // new future each rebuild
```

**Correct**

```dart
late final Future<int> future = api.load(); // create it once, in State
FutureBuilder<int>(future: future, builder: (context, snapshot) => const SizedBox.shrink());
```

Source: docs.flutter.dev/perf/best-practices
