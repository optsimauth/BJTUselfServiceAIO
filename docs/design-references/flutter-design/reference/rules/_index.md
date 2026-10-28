# Rule index

111 rules. Rule ID = filename. Load on demand.

## a11y- (14)

- `a11y-tap-target` [CRITICAL/P0] Targets at least 48dp (44pt on iOS)
- `a11y-target-spacing` [HIGH/P1] At least 8dp between targets
- `a11y-contrast-text` [CRITICAL/P1] Text contrast at least 4.5:1 (3:1 large)
- `a11y-contrast-ui` [HIGH/P1] UI components and icons 3:1
- `a11y-semantics-label` [CRITICAL/P0] Label every non-text control
- `a11y-merge-semantics` [MEDIUM/P2] Merge related text into one node
- `a11y-focus-visible` [HIGH/P1] Visible keyboard focus
- `a11y-focus-order` [MEDIUM/P2] Logical focus and reading order
- `a11y-not-color-only` [HIGH/P1] Never use color alone for meaning
- `a11y-disabled-opacity` [LOW/P3] Disabled at 0.38 content / 0.12 container
- `a11y-text-scale-2x` [CRITICAL/P0] Layout survives 2.0x text scale
- `a11y-bold-text` [LOW/P3] Respect Bold Text and high contrast settings
- `a11y-test-guidelines` [HIGH/P2] Enforce accessibility in widget tests
- `a11y-exclude-decorative` [LOW/P3] Hide decorative elements from semantics

## theme- (12)

- `theme-default-seed` [CRITICAL/P1] Never ship the default seed color
- `theme-raw-colors` [CRITICAL/P1] No raw colors in widgets
- `theme-inline-textstyle` [CRITICAL/P1] No inline font size or family in widgets
- `theme-brightness-branch` [HIGH/P1] Never branch on Brightness in widgets
- `theme-extension-tokens` [HIGH/P2] Custom tokens live in a ThemeExtension
- `theme-component-themes` [HIGH/P2] Style components once in ThemeData
- `theme-widget-state-property` [MEDIUM/P2] Use WidgetStateProperty for state styling
- `theme-light-dark-pair` [CRITICAL/P1] Provide theme and darkTheme together
- `theme-spacing-tokens` [HIGH/P2] Spacing from a 4/8 token scale
- `theme-radius-tokens` [MEDIUM/P2] Radius is a scale with a rule
- `theme-lerp` [LOW/P3] Theme switches should animate through lerp
- `theme-contrast-level` [LOW/P3] Offer contrast levels for accessibility

## state- (6)

- `state-loading-skeleton` [HIGH/P2] Skeleton for waits over ~1s
- `state-empty` [HIGH/P2] Empty states invite one action
- `state-error` [HIGH/P1] Errors state the cause and the fix
- `state-offline` [MEDIUM/P2] Design the offline state
- `state-success-feedback` [MEDIUM/P3] Confirm actions in context
- `state-destructive-undo` [CRITICAL/P1] Destructive actions offer undo or confirm

## layout- (13)

- `layout-grid-4-8` [MEDIUM/P2] Snap everything to a 4/8dp grid
- `layout-window-classes` [HIGH/P1] Branch on window size classes, not devices
- `layout-nav-switch` [HIGH/P1] Navigation changes shape with window class
- `layout-safearea` [CRITICAL/P1] Respect insets
- `layout-no-device-type` [HIGH/P1] Never check device type for layout
- `layout-sizeof-over-of` [MEDIUM/P2] Use MediaQuery.sizeOf, not MediaQuery.of
- `layout-max-content-width` [HIGH/P2] Cap content width on large screens
- `layout-card-soup` [HIGH/P2] No grids of identical cards
- `layout-rhythm` [MEDIUM/P2] Vary spacing to express grouping
- `layout-one-primary` [HIGH/P1] One primary action per screen
- `layout-sliver-scroll` [LOW/P3] Use slivers for collapsing and mixed lists
- `layout-keyboard-inset` [HIGH/P1] Forms must survive the keyboard
- `layout-no-fixed-sizes` [HIGH/P1] Avoid fixed heights for text containers

## platform- (12)

- `platform-adaptive-constructors` [MEDIUM/P2] Use .adaptive widgets where idiom matters
- `platform-cupertino-ios-idioms` [MEDIUM/P2] Honor iOS idioms on iOS
- `platform-scroll-physics` [LOW/P3] Use platform scroll physics
- `platform-predictive-back` [HIGH/P2] Support predictive back on Android
- `platform-haptics` [LOW/P3] Haptics once per commit, always with a visual
- `platform-material-ui-imports` [HIGH/P2] Match the project's material imports (Flutter 3.47+)
- `platform-dialogs` [MEDIUM/P2] Dialogs match the platform and name the action
- `platform-desktop-hover` [HIGH/P2] Design hover, focus and cursor for desktop/web
- `platform-web-selectable` [LOW/P3] On web, text is selectable and links are links
- `platform-expressive-optional` [LOW/P3] Material 3 Expressive is opt-in with a fallback
- `platform-liquid-glass-fallback` [LOW/P3] Liquid Glass needs a real fallback
- `platform-edge-to-edge` [MEDIUM/P2] Draw edge to edge, inset content

## color- (10)

- `color-seed-variant` [MEDIUM/P2] Choose the scheme variant deliberately
- `color-max-accent` [HIGH/P2] One accent per screen
- `color-no-pure-bw` [MEDIUM/P2] Tint neutrals; avoid pure black and white
- `color-tint-neutrals` [LOW/P3] Secondary text is tinted, not gray
- `color-semantic-status` [HIGH/P2] Status colors are semantic tokens
- `color-dark-desaturate` [HIGH/P1] Dark mode uses lighter, desaturated tones
- `color-surface-containers` [MEDIUM/P2] Elevate with surface container roles
- `color-on-pairs` [HIGH/P1] Pair every fill with its on-color
- `color-no-gradient-slop` [MEDIUM/P2] No decorative purple/blue gradients
- `color-dynamic-harmonize` [LOW/P3] Harmonize dynamic and custom colors

## type- (12)

- `type-roles-only` [HIGH/P1] Use Material type roles
- `type-two-families` [HIGH/P2] Choose at most two typefaces, on purpose
- `type-body-size` [HIGH/P1] Body text 14-16sp, never below 12sp
- `type-line-length` [MEDIUM/P2] Keep lines to 45-75 characters
- `type-tabular-figures` [MEDIUM/P2] Tabular figures for numbers that change or align
- `type-text-scaler` [CRITICAL/P0] Support user text scaling up to 200%
- `type-line-height` [LOW/P3] Set deliberate line height
- `type-weight-hierarchy` [MEDIUM/P2] Hierarchy by size and weight, 3 levels
- `type-no-allcaps-eyebrow` [MEDIUM/P2] No tracked ALL CAPS eyebrows or numbering chrome
- `type-variable-fonts` [LOW/P3] Use variable font axes when available
- `type-font-bundling` [MEDIUM/P2] Bundle fonts for production
- `type-overflow-handling` [HIGH/P1] Decide every text overflow

## motion- (14)

- `motion-frequency` [HIGH/P1] Animate by how often users see it
- `motion-durations` [HIGH/P2] Use a duration scale
- `motion-curves` [MEDIUM/P2] Use strong custom curves, not built-ins
- `motion-no-ease-in` [MEDIUM/P2] Never ease-in UI motion
- `motion-exit-faster` [MEDIUM/P3] Exits are faster than enters
- `motion-stagger` [LOW/P3] Stagger 30-50ms, never block input
- `motion-press-feedback` [HIGH/P1] Press feedback within 100ms
- `motion-springs` [LOW/P3] Springs for gestures and playful moments
- `motion-reduce` [CRITICAL/P1] Honor reduced motion with gentler alternatives
- `motion-implicit-first` [MEDIUM/P2] Prefer implicit animations
- `motion-transform-not-layout` [HIGH/P2] Animate transform and opacity, not layout
- `motion-interruptible` [MEDIUM/P2] Motion must be interruptible
- `motion-one-moment` [MEDIUM/P2] One orchestrated moment per screen
- `motion-page-transitions` [MEDIUM/P2] Use meaningful route transitions

## perf- (8)

- `perf-const` [MEDIUM/P3] Const constructors everywhere possible
- `perf-listview-builder` [HIGH/P1] Builders for long or unknown lists
- `perf-rebuild-scope` [MEDIUM/P2] Keep rebuilds local
- `perf-repaint-boundary` [LOW/P3] RepaintBoundary around heavy animated parts
- `perf-savelayer` [MEDIUM/P2] Avoid saveLayer triggers on large areas
- `perf-image-cache-size` [HIGH/P2] Decode images at display size
- `perf-profile-mode` [HIGH/P1] Judge smoothness in profile mode on a real device
- `perf-no-work-in-build` [HIGH/P1] No work in build()

## icon- (4)

- `icon-no-emoji` [HIGH/P2] No emoji as icons
- `icon-one-family` [MEDIUM/P2] One icon family and stroke weight
- `icon-size-tokens` [LOW/P3] Icon sizes are tokens
- `icon-filled-outline-state` [LOW/P3] Outline default, filled selected

## copy- (6)

- `copy-active-voice` [LOW/P3] Active voice, user's perspective
- `copy-specific-labels` [MEDIUM/P2] Specific button labels
- `copy-error-messages` [HIGH/P2] Error copy: cause plus fix, no blame
- `copy-no-lorem` [HIGH/P1] No placeholder content
- `copy-sentence-case` [LOW/P3] Sentence case for UI text
- `copy-consistent-verbs` [LOW/P3] One verb per intent
