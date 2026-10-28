---
title: No placeholder content
impact: HIGH
severity: P1
tags: [copy, slop]
---

# copy-no-lorem

**Impact: HIGH (P1)**

Lorem ipsum, John Doe, Acme, 'Title here' must not ship. Write real, domain-appropriate sample content.

**Incorrect**

```dart
Text('Lorem ipsum dolor sit amet')
```

**Correct**

```dart
Text('Morning run, 5.2 km, 31 min')
```

Source: Design review
