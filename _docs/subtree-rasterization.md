---
title: Subtree Rasterization
layout: docs
permalink: /docs/subtree-rasterization.html
prevPage: synchronous-concurrency.html
nextPage: drawing-priority.html
---

Flattening an entire view hierarchy into a single layer improves performance, but with UIKit, comes with a hit to maintainability and hierarchy-based reasoning. 

With all AsyncDisplayKit nodes, enabling precompositing is as simple as:

```
rootNode.shouldRasterizeDescendants = YES;
```

This line will cause the entire node hierarchy from that point on to be rendered into one layer.
