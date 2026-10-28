---
title: Outline default, filled selected
impact: LOW
severity: P3
tags: [icon, navigation]
---

# icon-filled-outline-state

**Impact: LOW (P3)**

Navigation destinations show `icon` (outline) and `selectedIcon` (filled) to communicate state without color alone.

**Incorrect**

```dart
NavigationDestination(icon: Icon(Icons.home), label: 'Home')
```

**Correct**

```dart
NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home')
```

Source: m3.material.io/components/navigation-bar
