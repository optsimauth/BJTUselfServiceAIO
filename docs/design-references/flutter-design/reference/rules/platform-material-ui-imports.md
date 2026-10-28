---
title: Match the project's material imports (Flutter 3.47+)
impact: HIGH
severity: P2
tags: [platform, migration]
---

# platform-material-ui-imports

**Impact: HIGH (P2)**

Material and Cupertino are moving to the `material_ui` and `cupertino_ui` packages. Do not mix `flutter/material.dart` and `material_ui` in one codebase; follow `pubspec.yaml`, migrate with `dart fix --apply`.

**Incorrect**

```dart
import 'package:flutter/material.dart'; // in a project already on material_ui
```

**Correct**

```dart
import 'package:material_ui/material_ui.dart';
```

Source: docs.flutter.dev/release
