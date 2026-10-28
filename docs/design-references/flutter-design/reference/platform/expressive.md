# Material 3 Expressive (optional)

Status (Flutter 3.47, Oct 2026): no official Flutter implementation; work is underway in `material_ui`. Community: `material_3_expressive` (needs Flutter 3.47+, `material_ui`, `motor`, `material_new_shapes`). Google's Expressive guidance is Compose-first. Verify the current state before using.

## When to use
Only when the brief wants personality (consumer, media, fitness, playful) and VARIANCE >= 7. Otherwise standard M3.

## Principles to apply with standard Flutter
- **Shape**: expressive shape set (cookie, clover, pill-with-notch); keep to one signature shape per screen. Use `ShapeBorder` and `material_new_shapes`; morph with `lerp`.
- **Color**: `DynamicSchemeVariant.expressive` or `vibrant`; larger tonal contrasts; still 4.5:1.
- **Type**: emphasized type styles (heavier weights, larger display); variable font axes.
- **Motion**: spatial springs (stiffness 300-700, damping ratio 0.6-0.9) for movement, effects springs (damping 1.0) for color/opacity. Use `motor` (`MotionController`, `Motion.expressiveSpatial`) instead of fixed curves.
- **Components**: button groups, split buttons, loading indicators (wavy), FAB menu, toolbar.

## Fallback contract
- Feature-flag every expressive component; fall back to the standard M3 widget with the same semantics.
- Never fake proprietary assets; label approximations in comments (`// Approximation of M3 Expressive ...`).
- Reduced motion: replace springs with 150ms fades.
