# animate

Add or review motion. Decide in this order; stop at the first "no".

1. **Should it animate at all?** Apply `motion-frequency`. Keyboard-initiated and 100+/day actions: no.
2. **Purpose**: spatial continuity, state change, explanation, feedback, preventing a jarring change. No purpose, no animation.
3. **Tool**: implicit widget first (`motion-implicit-first`); explicit controller for sequences/gestures; `animations` package for route transitions (`motion-page-transitions`); springs for drag-release (`motion-springs`).
4. **Properties**: transform and opacity only (`motion-transform-not-layout`).
5. **Curve and duration**: from `Motion` tokens (`motion-durations`, `motion-curves`, `motion-no-ease-in`). Dial tables in `dials.md`.
6. **Interrupt**: reverses from current value (`motion-interruptible`).
7. **Exit**: faster than enter (`motion-exit-faster`).
8. **Reduced motion**: gentler alternative (`motion-reduce`).
9. **One moment**: pick the single orchestrated moment per screen (`motion-one-moment`); strip the rest.

## Review output format
A single table: **Before | After | Why**. Verdict: Block or Approve. Fix order: delete, reduce, fix curve, fix origin, make interruptible, move to transform, asymmetric timing, polish, accessibility.

## Numbers
Press 100-160ms (scale 0.97). State 150-250ms. Overlay 200-300ms. Stagger 30-50ms. Exit about 0.65x enter. Spring damping 0.8-1.0.

## Verify
Profile mode on a device; no dropped frames; `flutter run --profile`; DevTools performance overlay.
