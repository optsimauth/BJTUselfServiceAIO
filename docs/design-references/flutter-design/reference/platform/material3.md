# Material 3 in Flutter

Material 3 is the default in Flutter 3.16+ (`useMaterial3` is true; do not set false). Use it as a toolbox, not a look.

## Color roles (45 in `ColorScheme`)
- Accent: `primary/onPrimary/primaryContainer/onPrimaryContainer`, same for `secondary`, `tertiary`; `error` set.
- Surfaces: `surface`, `surfaceDim`, `surfaceBright`, `surfaceContainerLowest/Low/(none)/High/Highest`, `onSurface`, `onSurfaceVariant`, `outline`, `outlineVariant`.
- Fixed: `primaryFixed`, `primaryFixedDim`, `onPrimaryFixed...` for colors that do not change with theme.
- Inverse: `inverseSurface`, `onInverseSurface`, `inversePrimary` (snack bars).
- Utility: `scrim`, `shadow`, `surfaceTint` (prefer container roles for depth).

## Shape scale (dp)
None 0, extra-small 4, small 8, medium 12, large 16, large-increased 20, extra-large 28, extra-large-increased 32, full. Assign by component role.

## State layers
Hover 8%, focus 10%, pressed 10%, dragged 16% of `onSurface`/content color over the container. Disabled content 38%, container 12%.

## Components to prefer
`FilledButton` (primary), `FilledButton.tonal`, `OutlinedButton`, `TextButton`; `NavigationBar/Rail/Drawer`; `SegmentedButton`; `SearchAnchor`; `SliverAppBar.large`; `ListTile`; `Card.filled/outlined`; `BottomSheet` with drag handle; `Badge`; `Chip` variants.

## Elevation
Express depth with tonal surface containers first; shadows only for floating elements (menus, FAB).

## Motion tokens
Easing: emphasized `Curves.easeInOutCubicEmphasized`, emphasizedDecelerate `Cubic(0.05, 0.7, 0.1, 1.0)`, emphasizedAccelerate `Cubic(0.3, 0, 0.8, 0.15)` (exits only), standard `Cubic(0.2, 0, 0, 1)`. Durations: short 50-200ms, medium 250-400ms, long 450-600ms.

## Avoid
Default seed, Roboto-by-accident, all components at default shape, FAB + AppBar action + filled button all at once.
