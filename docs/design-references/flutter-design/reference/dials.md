# Dials

Three integers, 1-10. Defaults: `VARIANCE 6`, `MOTION 4`, `DENSITY 5`. Infer from the brief, state them in the Design Read, never ask unless truly ambiguous.

## Vibe words to dials

| Brief says | VARIANCE | MOTION | DENSITY |
|------------|----------|--------|---------|
| government, banking, medical, enterprise | 2-3 | 2 | 5-6 |
| productivity, tools, dashboards | 3-4 | 2-3 | 7-8 |
| fintech consumer, commerce | 5 | 4 | 5 |
| social, media, fitness, habit | 7 | 6 | 4-5 |
| kids, games, playful | 8 | 8 | 3 |
| editorial, portfolio, luxury | 8-9 | 4-5 | 2-3 |
| brutalist, experimental | 10 | 3 | 5 |

## DENSITY to Dart

| Dial | Spacing scale (dp) | Page padding | `VisualDensity` | List tile height |
|------|--------------------|--------------|-----------------|------------------|
| 1-3 spacious | 8 12 16 24 32 48 64 | 24 | `standard` | 72 |
| 4-6 default | 4 8 12 16 24 32 48 | 16 | `standard` | 56 |
| 7-10 dense | 4 6 8 12 16 24 | 12 | `compact` (desktop/web only) | 40-48 |

Dense never goes below the 48dp target on touch devices. On mobile, density comes from tighter gaps, not smaller targets.

## MOTION to Dart

| Dial | Press | State change | Overlay / route | Stagger | Spring |
|------|-------|--------------|-----------------|---------|--------|
| 1-2 | none or 80ms | 120ms | 200ms | none | none |
| 3-5 | 120ms | 200ms | 250ms | 30ms | damping 1.0 |
| 6-8 | 140ms | 240ms | 300ms | 40ms | damping 0.85 |
| 9-10 | 160ms | 300ms | 400ms | 50ms | damping 0.75 |

Above 3, honor `MediaQuery.disableAnimationsOf` mandatorily (see `motion-reduce`).

## VARIANCE to Dart

| Dial | Shape | Layout | Color |
|------|-------|--------|-------|
| 1-3 | M3 default radii (12/16/28) | standard scaffolds | one seed, `tonalSpot` |
| 4-6 | custom radius scale, one signature shape | one asymmetric element per screen | `DynamicSchemeVariant.vibrant` or custom roles |
| 7-10 | mixed shapes with a rule (e.g. pill actions + square surfaces) | editorial, overlap, large type | hand-authored `ColorScheme`, accent used once |
