---
title: Navigation changes shape with window class
impact: HIGH
severity: P1
tags: [layout, navigation]
---

# layout-nav-switch

**Impact: HIGH (P1)**

Compact: `NavigationBar` (3-5 destinations, icon + label). Medium: `NavigationRail`. Expanded+: permanent `NavigationDrawer` or extended rail.

**Incorrect**

```dart
Scaffold(
  bottomNavigationBar: NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (_) {},
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
    ],
  ),
) // still a bottom bar on a 1400dp window
```

**Correct**

```dart
return switch (windowClassOf(context)) {
  WindowClass.compact => Scaffold(bottomNavigationBar: bar, body: page),
  WindowClass.medium => Row(children: [rail, Expanded(child: page)]),
  _ => Row(children: [drawer, Expanded(child: page)]),
};
```

Source: Material 3 layout, m3.material.io/foundations/layout
