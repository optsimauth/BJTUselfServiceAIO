---
title: Material 3 Expressive is opt-in with a fallback
impact: LOW
severity: P3
tags: [platform, expressive]
---

# platform-expressive-optional

**Impact: LOW (P3)**

No official Flutter implementation yet (Flutter 3.47). Use a documented community package or custom shapes/springs; keep a standard M3 fallback and label it in code.

**Incorrect**

```dart
// copying Compose Expressive visuals pixel-by-pixel with ad hoc shapes
```

**Correct**

```dart
// motor springs + material_new_shapes behind a feature flag; fallback = standard M3 components
```

Source: Flutter material_ui roadmap
