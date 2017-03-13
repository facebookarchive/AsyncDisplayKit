---
title: Placeholders
layout: docs
permalink: /docs/placeholder-fade-duration.html
prevPage: image-modification-block.html
nextPage: accessibility.html
---

## ASDisplayNodes may Implement Placeholders

Any `ASDisplayNode` subclass may implement the `-placeholderImage` method to provide a placeholder that covers content until a node's contents are finished displaying. To use placeholders, set `.placeholderEnabled = YES` and optionally set a `.placeholderFadeDuration`;

For image drawing, use the node's `.calculatedSize` property.

<div class = "note">
The `-placeholderImage` function may be called on a background thread, so it is important that this function is thread safe. Note that `-[UIImage imageNamed:]` is not thread safe when using image assets. Instead use `-[UIImage imageWithContentsOfFile:]`.
</div>


An ideal resource for creating placeholder images, including rounded rect solid colored ones or simple square corner ones is the `UIImage+ASConvenience` category methods in ASDK.

See our ancient <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples_extra/Placeholders">Placeholders sample app</a> to see this concept, first invented by the Facebook Paper team, in action. 

## `.neverShowPlaceholders`

Hear <a href="https://youtu.be/RY_X7l1g79Q">Scott Goodson explain</a> placeholders, `.neverShowPlaceholders` and why UIKit doesn't have them.  

## ASNetworkImageNode also have Default Images

In _addition_ to placeholders, `ASNetworkImageNode`s also have a `.defaultImage` property. While placeholders are meant to be transient, default images will persist if the image node's `.URL` property is `nil` or  if the URL fails to load. 

We suggest using default images for avatars, while using placeholder images for photos. 
