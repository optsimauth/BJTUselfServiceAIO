---
title: Haptics once per commit, always with a visual
impact: LOW
severity: P3
tags: [platform, feedback]
---

# platform-haptics

**Impact: LOW (P3)**

Fire on the same frame as the visual state change; selection tick for pickers, light impact for toggles, never on every scroll event.

**Incorrect**

```dart
onChanged: (v) { HapticFeedback.heavyImpact(); } // each slider tick
```

**Correct**

```dart
onChangeEnd: (_) => HapticFeedback.selectionClick()
```

Source: Apple HIG, Material haptics
