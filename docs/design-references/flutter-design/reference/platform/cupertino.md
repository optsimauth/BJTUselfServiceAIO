# Cupertino / iOS idioms

Use when the app should feel native on iOS/macOS, or in iOS-specific flows.

## Typography
SF-style system font on iOS. Body 17pt, subhead 15, footnote 13, caption 12/11 minimum, large title 34 bold. Honor Dynamic Type via text scaling.

## Structure
- `CupertinoNavigationBar` / `CupertinoSliverNavigationBar` (large title collapses).
- `CupertinoTabBar` with 2-5 tabs; keep state per tab (`CupertinoTabScaffold`).
- Swipe-from-edge back stays enabled (`CupertinoPageRoute`, do not block).
- Sheets: `showCupertinoModalPopup`, `CupertinoSheetRoute` with grabber; actions in `CupertinoActionSheet`.
- Lists: inset grouped (`CupertinoListSection.insetGrouped`), separators inset to text.

## Controls
`CupertinoSwitch`, `CupertinoSlider`, `CupertinoSegmentedControl`/`CupertinoSlidingSegmentedControl`, `CupertinoSearchTextField`, `CupertinoContextMenu`, `CupertinoPicker`/`CupertinoDatePicker`.

## Behavior
- Bounce scroll, pull-to-refresh (`CupertinoSliverRefreshControl`).
- Haptics: `HapticFeedback.selectionClick` for pickers, `lightImpact` for toggles.
- Targets 44x44pt minimum.
- Safe areas: dynamic island, home indicator; respect `MediaQuery.paddingOf`.
- Dark mode: use `CupertinoDynamicColor` or `CupertinoTheme` aligned with your `ColorScheme`.

## Mixing with Material
`MaterialApp` with `Theme.of(context).platform` driving idiom; `CupertinoTheme` wrapping Cupertino subtrees using `MaterialBasedCupertinoThemeData(materialTheme: Theme.of(context))` so colors and fonts match.

## Flutter 3.47+
Cupertino is moving to `cupertino_ui`; follow the project's imports (`platform-material-ui-imports`).
