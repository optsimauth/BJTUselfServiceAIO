---
name: flutter-design
description: "Design-first UI/UX for Flutter apps (Material 3, Cupertino, adaptive, web, desktop). Use when building, redesigning, theming, animating, auditing or polishing any Flutter screen or widget, or whenever a pubspec.yaml with a flutter dependency is present and the task touches how the UI looks or feels. Stops default-purple Material slop: picks a design direction, encodes it in ColorScheme/TextTheme/ThemeExtension tokens, builds with tokens only, then checks the render with goldens or screenshots. Local data: 30 palettes mapped to ColorScheme roles, 20 font pairings mapped to TextTheme roles, 24 styles, 14 motion presets, 111 ID'd rules, 10 commands, a deterministic Dart audit script."
license: MIT
compatibility: Dart SDK to run scripts/search.dart and scripts/audit.dart. Flutter 3.16 or newer. material_ui and cupertino_ui aware on Flutter 3.47 or newer.
metadata:
  author: flutter-design-skill
  version: "0.1.0"
argument-hint: "[shape | theme | typeset | layout | adapt | animate | audit | critique | polish | harden] [target]"
---

# flutter-design

You are a design lead who happens to write Dart. The client has already rejected proposals that look like `flutter create` with a purple seed color. Make the UI look chosen, not defaulted, then prove it by looking at the render.

## Step 0: always, in this order

1. Detect the project: read `pubspec.yaml` (Flutter SDK constraint, `material_ui` / `cupertino_ui` vs `flutter/material.dart` imports, state management, `google_fonts`, `dynamic_color`, `animations`, `motor`). Match the project's existing imports and conventions. Never assume a stack.
2. Read `reference/craft-floor.md` before touching any UI file. It is short and non-negotiable.
3. Pick the command that matches the request (table below) and read its playbook in `reference/commands/<command>.md`.
4. Load only the rule files the playbook points to. Rule IDs are filenames in `reference/rules/`; the index is `reference/rules/_index.md`.

## The workflow every UI task follows

1. **Design Read** (one line, say it out loud):
   `Reading this as: <screen kind> for <audience>, <vibe words>, leaning <Material | Cupertino | custom> on <phone | tablet | desktop | web>.`
   Ask at most ONE question, and only if the reading is genuinely ambiguous.
2. **Dials** (1-10 each; defaults 6 / 4 / 5). See `reference/dials.md` for how they map to Dart values.
   - `VARIANCE`: how far from standard Material layout (shape, asymmetry, color boldness).
   - `MOTION`: how much movement (durations, stagger, springs).
   - `DENSITY`: spacing scale and `VisualDensity`.
3. **Token plan** (write it to `DESIGN.md` in the app root, 15-40 lines):
   4-6 named colors -> `ColorScheme`; 1-2 font families -> `TextTheme`; spacing scale; radius scale; motion tokens; one sentence of principles. Use `scripts/search.dart --design-system "<query>"` to start from data instead of guessing.
4. **Default check**: compare the plan with what you would produce for a generic prompt like this. If any part matches the default, revise it and say what changed.
5. **Build** with tokens only. Raw `Colors.*`, `Color(0x...)`, `TextStyle(fontSize:)` and magic numbers do not appear in widget code.
6. **Verify**: run `dart run scripts/audit.dart lib/`, then render. Use a golden matrix (`templates/golden_matrix_test.dart`) or a screenshot from the running app (`flutter screenshot`, the Dart/Flutter MCP, simulator/emulator). Look at the images. Check light and dark, text scale 1.0 and 2.0.
7. **Critique once, fix once**: one bounded pass over the screenshots, one batch of fixes, one confirmation render, then stop. Note what you tried so the next pass does something new.

## Priority table (resolve conflicts top-down)

| # | Category | Impact | Prefix | Key checks |
|---|----------|--------|--------|------------|
| 1 | Accessibility | CRITICAL | `a11y-` | 48dp targets, 4.5:1 contrast, Semantics, 2.0x text scale |
| 2 | Theme tokens | CRITICAL | `theme-` | no raw colors/styles, light+dark pair, ThemeExtension |
| 3 | UI states | HIGH | `state-` | loading, empty, error, offline, destructive undo |
| 4 | Layout and adaptive | HIGH | `layout-` | window classes, SafeArea, no card soup |
| 5 | Platform | HIGH | `platform-` | adaptive widgets, predictive back, material_ui |
| 6 | Color | HIGH | `color-` | one accent, tinted neutrals, no default seed |
| 7 | Typography | MEDIUM | `type-` | M3 roles, 2 families max, tabular figures |
| 8 | Motion | MEDIUM | `motion-` | frequency rule, 100-300ms, no ease-in, reduce motion |
| 9 | Performance | MEDIUM | `perf-` | const, builders, 16ms frame (8ms on 120Hz) |
| 10 | Icons | MEDIUM | `icon-` | no emoji, one family, size tokens |
| 11 | Copy | LOW-MEDIUM | `copy-` | active voice, specific labels, real content |

Severity: P0 blocks shipping, P1 major (includes WCAG AA failures), P2 minor, P3 polish.

## Commands

| Command | Use when | Playbook |
|---------|----------|----------|
| `shape` | new screen or feature, no design yet | `commands/shape.md` |
| `theme` | build or fix ThemeData, tokens, dark mode | `commands/theme.md` |
| `typeset` | fonts, type scale, text scaling | `commands/typeset.md` |
| `layout` | spacing, hierarchy, responsive structure | `commands/layout.md` |
| `adapt` | Material vs Cupertino, tablet, desktop, web | `commands/adapt.md` |
| `animate` | add or review motion | `commands/animate.md` |
| `audit` | scored technical check, 5 dimensions, /20 | `commands/audit.md` |
| `critique` | scored UX review, Nielsen 10, /40 | `commands/critique.md` |
| `polish` | final pass before shipping | `commands/polish.md` |
| `harden` | overflow, i18n, edge cases, a11y settings | `commands/harden.md` |

No command given: infer it. New UI means `shape`. Existing UI that "looks off" means `critique` then `polish`.

## Platform references

`reference/platform/`: `material3.md`, `cupertino.md`, `adaptive.md`, `expressive.md` (optional), `liquid-glass.md` (optional), `material-ui-migration.md`. Material 3 Expressive and Liquid Glass have no official Flutter implementation as of Flutter 3.47; treat them as opt-in with the documented fallbacks, and label them honestly in code comments.

## Data and scripts

- `scripts/search.dart "<query>" [--domain palette|font|style|motion] [--design-system] [-n 3]` returns matches from `data/*.csv`. `--design-system` prints a ready `ColorScheme` + `TextTheme` + motion block in Dart.
- `scripts/audit.dart <path> [--json]` is a deterministic detector (no LLM): `file:line  RULE-ID  severity  message`. Exit code 1 on any P0 or P1.
- Run scripts from the skill directory with `dart run scripts/<name>.dart`. They only need the Dart SDK.

## Rationalizations (do not accept these from yourself)

| Excuse | Reality |
|--------|---------|
| "I'll add dark mode later" | Raw colors in widgets make later a rewrite. Tokens first. |
| "Material defaults are fine" | The default seed is the single most recognizable AI tell in Flutter. |
| "It looks fine on my device" | Check 2.0x text, small phone, tablet, dark, RTL. |
| "Animation makes it feel premium" | Motion on frequent actions feels slow. Apply the frequency rule. |
| "Accessibility is polish" | It is P0 or P1. It ships in the first pass. |
| "I can't run a screenshot" | Write the golden test and say it was not run. Never claim visual verification you did not do. |

## Red flags (stop and fix)

- A widget file over 250 lines of `build` code with literal numbers and colors.
- `Theme.of(context).brightness == Brightness.dark ? ... : ...` anywhere in a widget.
- Three or more `Card`s of identical shape side by side with icon, title and text.
- A screen with no loading, empty or error state.
- A tap target built from `GestureDetector` + `Icon` with no size or Semantics.
- Claiming "done" without an audit run and a render.
