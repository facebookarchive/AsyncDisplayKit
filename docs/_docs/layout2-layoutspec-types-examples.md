---
title: Layout Spec Composition Examples
layout: docs
permalink: /docs/layout2-layoutspec-types-examples.html
---

## Text Overlaid on an Image
<img src="/static/images/layoutSpec-examples/layout-example-inset-overlay.png" width="75%">

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  UIEdgeInsets *insets = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerWithInset = [ASInsetLayoutSpec alloc] initWithInsets:insets child:textNode];
  ...
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>