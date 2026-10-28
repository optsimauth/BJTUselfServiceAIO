# material_ui / cupertino_ui (Flutter 3.47+)

As of Flutter 3.47 (Aug 2026), Material and Cupertino libraries are published as `material_ui` and `cupertino_ui` on pub.dev (1.x, frequent releases). The in-SDK libraries were frozen from 3.44 and are scheduled for formal deprecation in the next stable. Verify against current release notes before migrating.

## Rule
Match the project. Check `pubspec.yaml` and existing imports:
- Uses `material_ui` -> `import 'package:material_ui/material_ui.dart';`
- Uses SDK -> `import 'package:flutter/material.dart';`
Never mix in one codebase.

## Migrating
1. Upgrade Flutter and Dart (3.47 needs Dart 3.13+).
2. Add `material_ui` and/or `cupertino_ui` to dependencies.
3. `dart fix --apply` to rewrite imports; run `flutter analyze`.
4. Check third-party packages that still import `flutter/material.dart` (they continue to work during the transition).
5. Re-run golden tests; small visual diffs are expected with new releases.

## For this skill
Rules and snippets use component names, which are identical across both. Only the import line differs. Prefer asking the project over assuming.
