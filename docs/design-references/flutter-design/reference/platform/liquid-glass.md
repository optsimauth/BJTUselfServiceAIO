# Liquid Glass (optional, iOS 26 style)

Status (Flutter 3.47): no official support; tracking issue flutter/flutter#170310, work moving to `cupertino_ui`. Label it as an approximation in code. Options:
- `liquid_glass_renderer` (experimental, needs Impeller + Flutter GPU preview; falls back to `FakeGlass`).
- `liquid_glass_native`: real SwiftUI `glassEffect` views via platform views on iOS 26+.
- Custom: `BackdropFilter` blur + tint + 1px highlight border.

## When to use
Floating controls over rich content on iOS: tab bars, toolbars, sheets, media controls. Not for body content surfaces, not everywhere.

## Rules
1. Glass floats over content; it is not a card style. One or two glass layers per screen.
2. Contrast: text on glass must reach 4.5:1 against the worst-case backdrop. Add a tint or scrim; test over white, black and busy photos.
3. Fallback tiers: iOS 26 native -> renderer package -> blur+tint -> solid `surfaceContainerHigh` (also when `MediaQuery.highContrastOf` or `disableAnimations` is on, and on low-end Android).
4. Performance: backdrop blur is expensive; limit area, use `RepaintBoundary`, test in profile mode on a real device.
5. Motion: morphing between glass elements uses springs (damping 0.8); reduced motion switches to fades.
6. Android/web/desktop: do not imitate iOS glass; use M3 surfaces.

## Fallback snippet
```dart
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 24});
  final Widget child; final double radius;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (MediaQuery.highContrastOf(context)) {
      return Material(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius), child: child);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.55),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}
```
