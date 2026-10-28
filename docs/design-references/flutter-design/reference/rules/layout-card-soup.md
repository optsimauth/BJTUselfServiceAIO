---
title: No grids of identical cards
impact: HIGH
severity: P2
tags: [layout, slop]
---

# layout-card-soup

**Impact: HIGH (P2)**

Icon + title + text in N identical rounded cards is the SaaS template. Vary scale, group with dividers or spacing, or use a list with strong hierarchy.

**Incorrect**

```dart
GridView.count(crossAxisCount: 3, children: List.generate(3, (_) => const FeatureCard()))
```

**Correct**

```dart
// One lead item (large), the rest as a divided list with trailing metadata
Column(children: [const LeadFeature(), ...rest.map(FeatureRow.new)])
```

Source: Design review
