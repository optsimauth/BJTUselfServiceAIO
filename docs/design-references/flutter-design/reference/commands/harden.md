# harden

Make the UI robust against real-world conditions.

## Test matrix
| Axis | Values |
|------|--------|
| Text scale | 1.0, 1.3, 2.0 |
| Locale | longest language (German +30%), RTL (Arabic/Hebrew), CJK |
| Size | 320x568, 360x800, 412x915, 820x1180, 1440x900, split-screen 400x900 |
| Theme | light, dark, high contrast |
| Data | empty, 1 item, 1000 items, very long strings, missing image, null fields |
| Network | slow, offline, error, timeout |
| Settings | bold text, reduce motion, screen reader on, large display size |

## Steps
1. Add the golden matrix (`templates/golden_matrix_test.dart`) for key screens.
2. Fix overflow: `Expanded`/`Flexible`, ellipsis, wrap, scroll (`type-overflow-handling`, `layout-no-fixed-sizes`).
3. RTL: use `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextDirection` aware icons (mirror back arrows).
4. Inputs: validation on blur, error summary, focus first error, keyboard type and actions, autofill hints, `viewInsets` (`layout-keyboard-inset`).
5. States: all `state-*` rules; image `errorBuilder` and `loadingBuilder`.
6. Accessibility tests: `meetsGuideline` set (`a11y-test-guidelines`).
7. Destructive actions: undo/confirm (`state-destructive-undo`).
8. Performance in profile mode on a low-end device.

## Never
- Treat overflow stripes as acceptable "debug only" issues.
