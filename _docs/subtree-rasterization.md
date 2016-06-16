---
title: Subtree Rasterization
layout: docs
permalink: /docs/subtree-rasterization.html
prevPage: synchronous-concurrency.html
nextPage: drawing-priority.html
---

Precompositing. Flattening an entire view hierarchy into a single layer also improves performance, but comes with a hit to maintainability and hierarchy-based reasoning. Nodes can do this for you too!

```
rootNode.shouldRasterizeDescendants = YES;
```

...will cause the entire node hierarchy from that point on to be rendered into one layer.

