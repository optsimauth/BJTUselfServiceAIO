# adapt

Make UI feel native on each platform and window size.

## Steps
1. Detect targets from `pubspec.yaml` folders (`ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`) and the project's design language (`material_ui` / `cupertino_ui` / Material only).
2. Window size classes drive structure (`platform/adaptive.md`): compact bottom bar, medium rail, expanded drawer/two-pane.
3. Platform idiom via `Theme.of(context).platform`, `.adaptive` constructors, `showAdaptiveDialog` (`platform-*`). Do not fork whole screens unless idiom truly differs.
4. Android: predictive back, edge-to-edge, dynamic color with harmonization.
5. iOS: swipe-back, large titles, sheets, haptics, 17pt body in Cupertino flows, safe areas.
6. Desktop/web: hover, cursors, focus rings, keyboard shortcuts, selectable text, resizable windows (`platform-desktop-hover`).
7. Verify with goldens at several sizes and `debugDefaultTargetPlatformOverride` for iOS and Android.

## Decision table
| Situation | Choice |
|-----------|--------|
| App identity is strong brand | One custom Material-based theme everywhere; `.adaptive` only for controls and dialogs |
| App should feel native per platform | Cupertino widgets on iOS/macOS, Material elsewhere, shared logic |
| Needs bleeding-edge look | Expressive / Liquid Glass modules behind flags with fallbacks |

## Never
- Use `Platform.isX` in widget code (breaks web and tests).
- Stretch a phone layout across a 1400dp window.
