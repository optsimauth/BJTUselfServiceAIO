---
title: Decide every text overflow
impact: HIGH
severity: P1
tags: [type, layout]
---

# type-overflow-handling

**Impact: HIGH (P1)**

Single-line: `maxLines: 1` + `overflow: TextOverflow.ellipsis`. Multi-line: allow growth. Inside Row, wrap in `Expanded`/`Flexible`.

**Incorrect**

```dart
Row(children: [const Icon(Icons.flag), Text(longTitle)])
```

**Correct**

```dart
Row(children: [const Icon(Icons.flag), Gap(8), Expanded(child: Text(longTitle, maxLines: 1, overflow: TextOverflow.ellipsis))])
```

Source: docs.flutter.dev
