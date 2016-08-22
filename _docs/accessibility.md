---
title: Accessibility
layout: docs
permalink: /docs/accessibility.html
prevPage: image-modification-block.html
nextPage: layer-backing.html
---

Accessibility works seamlessly in ways that even UIKit doesn’t provide. When using the powerful optimization features of <a href = "layer-backing.html">Layer Backing</a> (`.layerBacked`) and <a href = "subtree-rasterization.html">Subtree Rasterization</a> (`.shouldRasterizeDescendants`), VoiceOver can access fine-grained metadata about each element. This is pretty amazing: `CALayer` doesn’t support accessibility, and rasterization reduces everything to a single flat image. 

The AsyncDisplayKit team fundamentally believes in Accessibility, and invested the time to create an innovative system to make this possible with zero developer effort. As a bonus, this also allows Automated UI Testing greater access to the interface.