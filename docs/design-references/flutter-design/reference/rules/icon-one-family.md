---
title: One icon family and stroke weight
impact: MEDIUM
severity: P2
tags: [icon]
---

# icon-one-family

**Impact: MEDIUM (P2)**

Mixing Material Icons, Cupertino and custom sets looks unfinished. Choose one (Material Symbols with fixed weight/fill/grade, or Phosphor/Lucide).

**Incorrect**

```dart
Icon(Icons.home);
Icon(CupertinoIcons.search);
Icon(FontAwesomeIcons.user);
```

**Correct**

```dart
const Icon(Symbols.home, weight: 400.0);
const Icon(Symbols.search, weight: 400.0);
```

Source: m3.material.io/styles/icons
