---
title: Custom tokens live in a ThemeExtension
impact: HIGH
severity: P2
tags: [theme, tokens]
---

# theme-extension-tokens

**Impact: HIGH (P2)**

Spacing, radii, motion and brand colors that ColorScheme lacks belong in a `ThemeExtension` with `copyWith` and `lerp`, accessed through one context extension.

**Incorrect**

```dart
const kCardRadius = 14.0; // global constant, no dark/brand variants
```

**Correct**

```dart
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.radiusM, required this.success});
  final double radiusM; final Color success;
  @override AppTokens copyWith({double? radiusM, Color? success}) => AppTokens(radiusM: radiusM ?? this.radiusM, success: success ?? this.success);
  @override AppTokens lerp(AppTokens? o, double t) => o == null ? this : AppTokens(radiusM: lerpDouble(radiusM, o.radiusM, t)!, success: Color.lerp(success, o.success, t)!);
}
extension TokensX on BuildContext { AppTokens get tokens => Theme.of(this).extension<AppTokens>()!; }
```

Source: Flutter docs, docs.flutter.dev/ui/design/material
