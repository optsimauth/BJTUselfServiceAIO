---
title: On web, text is selectable and links are links
impact: LOW
severity: P3
tags: [platform, web]
---

# platform-web-selectable

**Impact: LOW (P3)**

Wrap content in `SelectionArea`; use real URLs for navigation; handle back/forward via router.

**Incorrect**

```dart
Text(article)
```

**Correct**

```dart
SelectionArea(child: Text(article))
```

Source: docs.flutter.dev/platform-integration/web
