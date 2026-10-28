# shape

Plan and build a new screen or feature with a deliberate design direction.

## Steps
1. Read `craft-floor.md`. Inspect `pubspec.yaml` and any existing `lib/theme/`, `DESIGN.md`.
2. If the subject is not named, propose one line (subject, audience, primary job) and continue; ask only if truly ambiguous.
3. Write the **Design Read** and set the **dials** (`reference/dials.md`).
4. Find the subject's visual vocabulary: materials, industry, vernacular. Distinctive choices come from there, not from "modern and clean".
5. Run `dart run scripts/search.dart "<subject vibe words>" --design-system`. Treat it as a starting point; adjust at least one decision.
6. Write `DESIGN.md`:
   - 4-6 named colors with roles, light and dark.
   - 1-2 font families and which TextTheme roles they take.
   - Spacing and radius scales; shape rule.
   - Motion tokens; the one orchestrated moment.
   - A small ASCII wireframe of each screen with alignment and hierarchy (one primary action).
7. Default check: "What would I produce for a generic prompt?" If the plan matches, change it and say what changed.
8. Build theme first (`theme.md`), then screens with tokens only. Include loading, empty, error states (`state-*`).
9. Verify: `audit.dart`, golden matrix or screenshot, light/dark, 1.0 and 2.0 text scale. One critique pass, one fix batch.

## Output
- Design Read line, dials, token plan summary, files changed, audit result, what was rendered and checked (or explicitly "not rendered").

## Never
- Start with widgets before tokens.
- Use the default seed, raw colors, or inline text styles.
- Claim visual verification without a render.
