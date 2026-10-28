---
title: Use slivers for collapsing and mixed lists
impact: LOW
severity: P3
tags: [layout, scroll]
---

# layout-sliver-scroll

**Impact: LOW (P3)**

`CustomScrollView` with `SliverAppBar.large` and `SliverList` gives native-feeling collapse without nested scrollables.

**Incorrect**

```dart
Column(children: [Header(), ListView(shrinkWrap: true)])
```

**Correct**

```dart
CustomScrollView(slivers: [
  const SliverAppBar.large(title: Text('Inbox')),
  SliverList.builder(itemBuilder: (context, index) => const SizedBox.shrink(), itemCount: n),
])
```

Source: docs.flutter.dev
