# typeset

Fonts, type scale and text scaling.

## Steps
1. Audit current usage: inline `TextStyle(fontSize:)`, `fontFamily`, text overflow, text scaler overrides.
2. Choose 1-2 families from the brief: `search.dart --domain font "<mood>"`. Check the font supports the app's languages (Latin ext, Devanagari, Arabic, CJK) and needed weights/tabular figures.
3. Map to `TextTheme` roles. Typical: display/headline use the display face; title/body/label use the text face. Set `height` per role (`type-line-height`).
4. Bundle fonts for release (`type-font-bundling`); declare variable axes if used (`type-variable-fonts`).
5. Numbers: tabular figures for prices, timers, tables (`type-tabular-figures`).
6. Replace inline styles with roles. Overflow decision for every Text (`type-overflow-handling`).
7. Test at `TextScaler.linear(2.0)` and with the longest localized strings (+30-40%).

## Scale reference (sp)
| Role | Size / height | Weight |
|------|---------------|--------|
| displayLarge | 57 / 64 | 400 |
| headlineMedium | 28 / 36 | 400-600 |
| titleLarge | 22 / 28 | 500-600 |
| titleMedium | 16 / 24 | 500 |
| bodyLarge | 16 / 24 | 400 |
| bodyMedium | 14 / 20 | 400 |
| labelLarge | 14 / 20 | 500 |
| labelSmall | 11 / 16 | 500 |

Body never below 14 for primary reading text; nothing below 12.

## Never
- More than 2 families, ALL CAPS eyebrow chrome, hardcoded sizes, disabling text scaling globally.
