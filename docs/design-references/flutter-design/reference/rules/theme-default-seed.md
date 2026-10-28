---
title: Never ship the default seed color
impact: CRITICAL
severity: P1
tags: [theme, color, slop]
---

# theme-default-seed

**Impact: CRITICAL (P1)**

`Colors.deepPurple` / `0xFF6750A4` is the Flutter template look. Choose a seed from the brief's subject, or hand-author the scheme.

**Incorrect**

```dart
ColorScheme.fromSeed(seedColor: Colors.deepPurple)
```

**Correct**

```dart
// Seed derived from the brand (deep teal for a tide-tracking app)
ColorScheme.fromSeed(seedColor: const Color(0xFF0F6B72), dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot)
```

Source: Material 3 spec, m3.material.io
