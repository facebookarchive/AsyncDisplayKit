---
title: Layer Backing
layout: docs
permalink: /docs/layer-backing.html
next: synchronous-concurrency.html
---

Layer-backing. In some cases, you can substantially improve your app's performance by using layers instead of views. Manually converting view-based code to layers is laborious due to the difference in APIs. Worse, if at some point you need to enable touch handling or other view-specific functionality, you have to manually convert everything back (and risk regressions!).

With nodes, converting an entire subtree from views to layers is as simple as...

```
rootNode.layerBacked = YES;
```

...and if you need to go back, it's as simple as deleting one line. We recommend enabling layer-backing as a matter of course in any custom node that doesn't need touch handling.

