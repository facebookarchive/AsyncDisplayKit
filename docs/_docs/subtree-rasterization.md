---
title: Subtree Rasterization
layout: docs
permalink: /docs/subtree-rasterization.html
prevPage: layer-backing.html
nextPage: synchronous-concurrency.html
---

Flattening an entire view hierarchy into a single layer improves performance, but with UIKit, comes with a hit to maintainability and hierarchy-based reasoning. 

With all AsyncDisplayKit nodes, enabling precompositing is as simple as:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
rootNode.shouldRasterizeDescendants = YES;
</pre>
<pre lang="swift" class = "swiftCode hidden">
rootNode.shouldRasterizeDescendants = true
</pre>
</div>
</div>
<br>

This line will cause the entire node hierarchy from that point on to be rendered into one layer.
