# Craft floor

Read before every UI edit. These hold regardless of the brief unless the brief explicitly overrides one, and then say so in the Design Read.

## Flutter AI-slop tells (refuse)

Each has an audit rule. Run `dart run scripts/audit.dart lib/` to catch them.

| Tell | Why it reads as generated | Rule |
|------|---------------------------|------|
| `ColorScheme.fromSeed(seedColor: Colors.deepPurple)` or `0xFF6750A4` unchanged | The `flutter create` look | `theme-default-seed` |
| Raw `Colors.blue`, `Color(0xFF...)` inside widgets | Breaks dark mode and rebrand | `theme-raw-colors` |
| `TextStyle(fontSize: 18, fontWeight: ...)` inline | Bypasses the type scale | `theme-inline-textstyle` |
| `brightness == Brightness.dark ? a : b` in a widget | Theme leak | `theme-brightness-branch` |
| Grid of identical `Card`s with icon + title + text | SaaS card kit | `layout-card-soup` |
| One radius on every surface | No shape language | `theme-radius-tokens` |
| `AnimatedContainer` / fade-slide on every item | Motion as decoration | `motion-one-moment` |
| Emoji as icons | Inconsistent, unscalable | `icon-no-emoji` |
| Stock `AppBar` + `FloatingActionButton` on every screen | No hierarchy decision | `layout-one-primary` |
| `EdgeInsets.all(16)` everywhere | No rhythm | `layout-rhythm` |
| Eyebrow labels (tiny ALL CAPS above titles), `01 / 02 / 03` numbering, gradient hero metric | Template chrome | `type-no-allcaps-eyebrow` |
| `Lorem ipsum`, "John Doe", "Acme" | Placeholder content shipped | `copy-no-lorem` |
| Purple-to-blue gradients, glow shadows as the main affordance | Default AI palette | `color-no-gradient-slop` |
| Roboto only, never chosen | Default font | `type-two-families` |
| Pure `#000000` / `#FFFFFF` backgrounds | Harsh, untinted | `color-no-pure-bw` |

## Quality floor (do it without announcing it)

1. Light and dark `ThemeData` both exist and both pass contrast.
2. Every tappable thing is at least 48x48dp (44pt on iOS) with 8dp between neighbors, and has a Semantics label.
3. Layout survives `TextScaler.linear(2.0)` with no overflow stripes.
4. `SafeArea` or `MediaQuery.paddingOf` respected; keyboard does not cover the focused field.
5. Loading, empty, error states exist for every async surface.
6. Reduced motion (`disableAnimationsOf`) respected; no motion needed to understand state.
7. Works at 360dp wide, and does not stretch past ~840dp content width on large screens.
8. No `print`, no debug banner, no placeholder strings.

## Restraint

Spend boldness in one place per screen: a single signature color use, a single large type moment, a single shape idea, a single orchestrated animation. Everything else supports it.

## Brief overrides

The user's own words beat this file. If they ask for purple, gradients or Material defaults, deliver them well and note the tradeoff in one line.

## Red flags and rationalizations

See `SKILL.md`. If you catch yourself using one, stop.
