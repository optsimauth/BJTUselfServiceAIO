# theme

Build or repair `ThemeData`, tokens and dark mode.

## Steps
1. Locate the theme (`MaterialApp(theme:)`). If raw colors are scattered, run `audit.dart` and list counts for `theme-raw-colors`, `theme-inline-textstyle`, `theme-brightness-branch`.
2. Choose the scheme: `search.dart --domain palette "<vibe>"`, or derive a seed from the brand. Decide the variant (`color-seed-variant`). Build light and dark from the same source (`theme-light-dark-pair`, `color-dark-desaturate`).
3. Verify contrast of every `on*` pair in both themes (`a11y-contrast-text`, `color-on-pairs`). Fix by changing the seed/tone, not by hardcoding in widgets.
4. TextTheme: apply the font pair (`typeset.md`).
5. Component themes once in ThemeData (`theme-component-themes`): buttons, inputs, cards, app bar, nav bar, dialogs, chips, snack bars, with `WidgetStateProperty` for states.
6. Tokens in a `ThemeExtension` (`templates/app_theme.dart`): spacing, radius, motion, status colors, with `copyWith` and `lerp`.
7. Replace raw usages in widgets with roles/tokens; remove brightness branches.
8. Render a theme gallery golden (all roles and components) in light and dark.

## Checklist
- [ ] seed is not default; variant chosen
- [ ] light + dark pair; `themeMode: system`
- [ ] status colors harmonized; semantic tokens
- [ ] component themes cover focus, hover, pressed, disabled
- [ ] high contrast level wired (`theme-contrast-level`)

## Never
- Invert colors for dark mode.
- Put hex literals in widget files.
