# audit

Technical quality check, scored 0-4 on five dimensions, total /20.

## Run
1. `dart run scripts/audit.dart lib/` (deterministic findings with rule IDs).
2. Read the findings, then inspect what the script cannot see (contrast, hierarchy, real device behavior).
3. Score, report, end with the next command.

## Dimensions
| Dimension | Checks | Rules |
|-----------|--------|-------|
| Accessibility | targets, semantics, contrast, text scale, focus, reduce motion | `a11y-*`, `motion-reduce`, `type-text-scaler` |
| Theming | raw colors, inline styles, light+dark, tokens, component themes | `theme-*`, `color-*` |
| Responsive | window classes, insets, fixed sizes, max width, nav switch | `layout-*`, `platform-*` |
| Performance | const, builders, rebuild scope, saveLayer, image decode, profile mode | `perf-*`, `motion-transform-not-layout` |
| Design integrity | slop tells, states, icons, copy | craft-floor, `state-*`, `icon-*`, `copy-*` |

Scoring per dimension: 4 none found, 3 P3 only, 2 P2 present, 1 any P1, 0 any P0.

## Bands
18-20 Excellent, 14-17 Good, 10-13 Acceptable, 6-9 Poor, 0-5 Critical.

## Report format
```
Audit score: 13/20 (Acceptable)
A11y 2 | Theming 1 | Responsive 3 | Performance 4 | Integrity 3
P1 lib/home.dart:42  theme-raw-colors  Colors.blue in Container
  Fix: cs.primaryContainer. Next: /theme
...
Next: run polish, then re-run audit to see the score improve.
```
Each finding: Location, rule ID, severity, one-line fix, suggested command.

## Never
- Report style nitpicks as P0/P1.
- Fix anything during an audit; report only.
