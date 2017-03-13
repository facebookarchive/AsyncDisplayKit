---
title: Layer Backing
layout: docs
permalink: /docs/layer-backing.html
prevPage: accessibility.html
nextPage: subtree-rasterization.html
---

In some cases, you can substantially improve your app's performance by using layers instead of views. **We recommend enabling layer-backing in any custom node that doesn't need touch handling**.

With UIKit, manually converting view-based code to layers is laborious due to the difference in APIs. Worse, if at some point you need to enable touch handling or other view-specific functionality, you have to manually convert everything back (and risk regressions!).

With all AsyncDisplayKit nodes, converting an entire subtree from views to layers is as simple as:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
rootNode.layerBacked = YES;
</pre>
<pre lang="swift" class = "swiftCode hidden">
rootNode.layerBacked = true
</pre>
</div>
</div>

...and if you need to go back, it's as simple as deleting one line. 


