---
title: Theme switches should animate through lerp
impact: LOW
severity: P3
tags: [theme, motion]
---

# theme-lerp

**Impact: LOW (P3)**

`ThemeExtension.lerp` must interpolate, not snap, so `AnimatedTheme` changes feel continuous.

**Incorrect**

```dart
class _SnapTokens extends AppTokens {
  const _SnapTokens() : super(success: const Color(0xFF2E7D4F));
  @override
  AppTokens lerp(AppTokens? o, double t) => this;
}
```

**Correct**

```dart
class _LerpTokens extends AppTokens {
  const _LerpTokens({required super.success});
  @override
  AppTokens lerp(AppTokens? other, double t) => other == null
      ? this
      : _LerpTokens(success: Color.lerp(success, other.success, t)!);
}
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
