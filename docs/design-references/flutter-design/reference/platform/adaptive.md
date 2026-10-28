# Adaptive layout

## Window size classes (width, dp)
| Class | Range | Columns | Margins | Navigation | Content pattern |
|-------|-------|---------|---------|------------|-----------------|
| Compact | < 600 | 4 | 16 | `NavigationBar` (3-5) | single pane, push detail |
| Medium | 600-839 | 8 | 24 | `NavigationRail` | list + optional detail, or single pane |
| Expanded | 840-1199 | 12 | 24 | rail or permanent `NavigationDrawer` | list-detail two-pane |
| Large | 1200-1599 | 12 | 24+ | permanent drawer | two-pane, optional third pane |
| Extra-large | 1600+ | 12 | 24+ | permanent drawer | multi-pane, capped content widths |

## Canonical layouts
- **List-detail**: `Row(children: [SizedBox(width: 360, child: list), VerticalDivider, Expanded(detail)])` on expanded; push on compact. Keep selection in state/router so rotation or resize preserves it.
- **Feed**: columns grow with width (1, 2, 3) via `SliverGridDelegateWithMaxCrossAxisExtent`.
- **Supporting pane**: primary content + 320-400dp side pane for tools/inspector.

## Rules
- Use `MediaQuery.sizeOf` or `LayoutBuilder` with the constraints you actually get (a widget in a pane is not the window).
- Do not lock orientation; support resizing, foldables (`MediaQuery.displayFeaturesOf`) and multi-window.
- Preserve state across layout changes (keys, `PageStorageKey`, router).
- Cap line length; center or two-pane beyond 840dp.
- Input: touch targets 48dp; pointer adds hover/focus; keyboard adds shortcuts and traversal.
- Test goldens at 360x800, 600x900, 840x900, 1280x800.

## Helper
```dart
enum WindowClass { compact, medium, expanded, large, extraLarge }
WindowClass windowClassOf(double w) =>
    w < 600 ? WindowClass.compact : w < 840 ? WindowClass.medium
  : w < 1200 ? WindowClass.expanded : w < 1600 ? WindowClass.large : WindowClass.extraLarge;
```
