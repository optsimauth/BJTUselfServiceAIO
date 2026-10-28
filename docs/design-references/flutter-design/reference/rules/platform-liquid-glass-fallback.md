---
title: Liquid Glass needs a real fallback
impact: LOW
severity: P3
tags: [platform, ios]
---

# platform-liquid-glass-fallback

**Impact: LOW (P3)**

No official support yet (flutter/flutter#170310). If used: iOS 26+ via platform view or `liquid_glass_renderer`, otherwise `BackdropFilter` blur + 1px border + tint; keep contrast 4.5:1 over any backdrop.

**Incorrect**

```dart
BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Text('x')) // contrast unchecked
```

**Correct**

```dart
// Scrim measured against worst-case backdrop; solid fallback when MediaQuery.highContrastOf or Impeller unavailable
```

Source: Apple HIG, flutter/flutter#170310
