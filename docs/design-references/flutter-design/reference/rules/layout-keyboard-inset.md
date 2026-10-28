---
title: Forms must survive the keyboard
impact: HIGH
severity: P1
tags: [layout, forms]
---

# layout-keyboard-inset

**Impact: HIGH (P1)**

Scroll the focused field into view; pad with `viewInsets.bottom` or rely on `Scaffold.resizeToAvoidBottomInset` with a scrollable body.

**Incorrect**

```dart
Column(children: [TextField(), TextField(), const Spacer(), button])
```

**Correct**

```dart
SingleChildScrollView(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form)
```

Source: docs.flutter.dev/ui/adaptive-responsive
