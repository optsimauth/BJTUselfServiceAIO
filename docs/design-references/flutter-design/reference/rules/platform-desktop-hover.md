---
title: Design hover, focus and cursor for desktop/web
impact: HIGH
severity: P2
tags: [platform, desktop]
---

# platform-desktop-hover

**Impact: HIGH (P2)**

Pointer devices need hover states, `MouseRegion` cursors, tooltips, keyboard shortcuts (`Shortcuts`/`Actions`) and visible focus. Hover effects only where hover exists.

**Incorrect**

```dart
InkWell(onTap: f, child: row) // no cursor change on custom widget
```

**Correct**

```dart
MouseRegion(cursor: SystemMouseCursors.click, child: InkWell(onTap: f, hoverColor: cs.onSurface.withValues(alpha: 0.08), child: row))
```

Source: docs.flutter.dev/ui/adaptive-responsive/capabilities
