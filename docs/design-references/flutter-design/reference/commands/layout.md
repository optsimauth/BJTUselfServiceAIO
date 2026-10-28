# layout

Spacing, hierarchy and responsive structure.

## Steps
1. Identify the one primary action and the 1-2 pieces of information that matter most on each screen (`layout-one-primary`).
2. Apply spacing tokens with rhythm: related 4-8, groups 16-24, sections 32-48 (`layout-rhythm`, `layout-grid-4-8`).
3. Replace card soup (`layout-card-soup`): one lead element, the rest as a divided list or varied scale.
4. Insets: `SafeArea`, keyboard inset, scroll padding (`layout-safearea`, `layout-keyboard-inset`).
5. Responsive: window classes, content max width, navigation switch (`layout-window-classes`, `layout-max-content-width`, `layout-nav-switch`). Details in `adapt.md`.
6. Remove fixed heights on text containers (`layout-no-fixed-sizes`). Use `MediaQuery.sizeOf`.
7. Render at 360x640, 412x915, 820x1180, 1440x900; text 1.0 and 2.0.

## Hierarchy test
Squint at the screenshot: can you tell the primary action and the main information in 2 seconds? If not, reduce competing emphasis before adding anything.

## Never
- Use device type checks or lock orientation to avoid responsive work.
- Make every block the same padding and radius.
