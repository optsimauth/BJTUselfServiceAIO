---
title: Enforce accessibility in widget tests
impact: HIGH
severity: P2
tags: [a11y, testing]
---

# a11y-test-guidelines

**Impact: HIGH (P2)**

Add guideline expectations for every screen.

**Incorrect**

```dart
testWidgets('home', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: Text('Home')));
}); // no guidelines
```

**Correct**

```dart
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(textContrastGuideline));
```

Source: docs.flutter.dev/ui/accessibility
