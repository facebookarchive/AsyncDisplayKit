---
title: ASButtonNode
layout: docs
permalink: /docs/button-node.html
prevPage: control-node.html
nextPage: text-node.html
---

`ASButtonNode` (a subclass of `ASControlNode`) supports simple buttons, with multiple states for a text label and an image with a few different layout options. Enables layerBacking for subnodes to significantly lighten main thread impact relative to UIButton (though async preparation is the bigger win).

Features:
- supports state-changing background images
- supports state-changing titles
- supports text alignment
- supports contentEdgeInsets
- offers methods that allow more convenient usage than creating attributed strings — title NSString, UIFont, and UIColor. 

Gotchas:
- the `selected` property logic should be handled by the developer. Tapping the ASButtonNode does not automatically enable selected. 
