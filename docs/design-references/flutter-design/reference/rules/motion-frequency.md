---
title: Animate by how often users see it
impact: HIGH
severity: P1
tags: [motion]
---

# motion-frequency

**Impact: HIGH (P1)**

100+ times a day (tab switches, list taps, shortcuts): no animation. Tens per day: minimal. Occasional (sheets, dialogs): standard. Rare or first-run: delight allowed.

**Incorrect**

```dart
// 120ms slide + fade on every tab content switch
```

**Correct**

```dart
// Tab body swaps instantly; only the indicator moves (100ms)
```

Source: Emil Kowalski animation principles (adapted)
