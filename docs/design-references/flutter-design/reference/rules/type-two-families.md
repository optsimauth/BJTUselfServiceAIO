---
title: Choose at most two typefaces, on purpose
impact: HIGH
severity: P2
tags: [type, slop]
---

# type-two-families

**Impact: HIGH (P2)**

Default Roboto everywhere is unchosen. Pick a display + text pair (see `data/fonts.csv`) or one versatile family; map to `TextTheme`.

**Incorrect**

```dart
ThemeData(useMaterial3: true) // fonts never considered
```

**Correct**

```dart
final text = GoogleFonts.dmSansTextTheme(base).copyWith(displayLarge: GoogleFonts.fraunces(textStyle: base.displayLarge))
```

Source: Typographic hierarchy
