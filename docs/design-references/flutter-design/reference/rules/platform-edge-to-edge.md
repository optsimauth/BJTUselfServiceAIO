---
title: Draw edge to edge, inset content
impact: MEDIUM
severity: P2
tags: [platform, android]
---

# platform-edge-to-edge

**Impact: MEDIUM (P2)**

Android 15+ enforces edge-to-edge. Let the scaffold draw behind system bars and pad content; set transparent bars with proper icon brightness.

**Incorrect**

```dart
SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.black))
```

**Correct**

```dart
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
```

Source: developer.android.com edge-to-edge
