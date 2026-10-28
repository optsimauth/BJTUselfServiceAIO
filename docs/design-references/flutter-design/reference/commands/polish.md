# polish

Final pass before shipping. Bounded: one inspection, one fix batch, one confirmation.

## Steps
1. Establish the system: read `DESIGN.md`, theme, tokens. Polish conforms to the system, it does not invent a new one.
2. Gather evidence: `audit.dart` + screenshot matrix (light/dark, 1.0/2.0 text, compact/expanded).
3. Triage by severity (P0 to P3).
4. Fix in this order: flow and hierarchy, spacing rhythm, color roles and contrast, type roles, states (loading/empty/error/pressed/focused/disabled), motion (remove extras, fix curves), copy (verbs, errors), icons (family, size).
5. Alignment and optical details: icon-text baseline, 1px borders vs tonal surfaces, consistent radii by role, no clipped shadows, no overflow stripes.
6. Re-run audit and one render; confirm. Stop.

## Checklist (honestly tick or it is not done)
- [ ] no audit P0/P1
- [ ] light and dark checked visually
- [ ] 2.0x text scale checked
- [ ] every async surface has loading/empty/error
- [ ] one primary action per screen
- [ ] targets 48dp, labels present
- [ ] reduced motion path
- [ ] no placeholder copy, no debug banner
- [ ] one accent, tinted neutrals, no default seed

## Never
- Introduce new tokens during polish unless a gap is proven.
