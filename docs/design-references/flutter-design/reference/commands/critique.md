# critique

UX review from rendered screens, scored with Nielsen's 10 heuristics, 0-4 each, total /40. Most real interfaces land 20-32.

## Steps
1. Render first: goldens/screenshots for main flows, light and dark, 1.0 and 2.0 text scale, phone and tablet. No render, no critique; say so.
2. Score each heuristic with evidence (screen + element). Mark n/a and renormalize.
3. Persona red flags: first-time user, power user, one-handed commuter, low-vision user at 200% text.
4. Cognitive load: count competing primary elements per screen (target 1); choices per step (target 7 or fewer).
5. Slop check against `craft-floor.md`.
6. Prioritize: P0 blocks, P1 major, P2 minor, P3 polish. Max 8 findings, strongest first.

## Heuristics
1 Visibility of status (loading, progress, confirmation) | 2 Match with real world (copy, icons) | 3 User control (undo, back, cancel) | 4 Consistency (components, verbs, platform idiom) | 5 Error prevention | 6 Recognition over recall | 7 Flexibility (shortcuts, adaptive) | 8 Minimalist design | 9 Error recovery | 10 Help and docs / onboarding.

## Finding format
`[P1] Screen/element | Heuristic | Impact | Recommendation | Command (e.g. /layout)`

## Never
- Praise-pad. Name what works in one line, then findings.
- Suggest changes you cannot tie to a visible issue.
