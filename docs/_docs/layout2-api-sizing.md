---
title: Layout API Sizing
layout: docs
permalink: /docs/layout2-api-sizing.html
nextPage: layout-transition-api.html
---

The easiest way to understand the compound dimension types in the Layout API is to see all the units in relation to one another.

<img src="/static/images/layout2-api-sizing.png">

## Values (`CGFloat`, `ASDimension`)
<br>
`ASDimension` is essentially a **normal CGFloat with support for representing either a point value, a relative percentage value, or an auto value**.  

This unit allows the same API to take in both fixed values, as well as relative ones.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
<b>// dimension returned is relative (%)</b>
ASDimensionMake(@"50%");  
ASDimensionMakeWithFraction(0.5);

<b>// dimension returned in points</b>
ASDimensionMake(@"70pt")
ASDimensionMake(70);      
ASDimensionMakeWithPoints(70);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

### Example using `ASDimension`

`ASDimension` is used to set the `flexBasis` property on a child of an `ASStackLayoutSpec`.  The `flexBasis` property specifies an object's initial size in the stack dimension, where the stack dimension is whether it is a horizontal or vertical stack.

In the following view, we want the left stack to occupy `40%` of the horizontal width and the right stack to occupy `60%` of the width. 

<img src="/static/images/flexbasis.png" width="40%" height="40%">

We do this by setting the `.flexBasis` property on the two childen of the horizontal stack:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
self.leftStack.style.flexBasis = ASDimensionMake(@"40%");
self.rightStack.style.flexBasis = ASDimensionMake(@"60%");

[horizontalStack setChildren:@[self.leftStack, self.rightStack]];
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Sizes (`CGSize`, `ASLayoutSize`)

`ASLayoutSize` is similar to a `CGSize`, but its **width and height values may represent either a point or percent value**. The type of the width and height are independent; either one may be a point or percent value.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
ASLayoutSizeMake(ASDimension width, ASDimension height);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

<br>
`ASLayoutSize` is used for setting a layout element's `.preferredLayoutSize`, `.minLayoutSize` and `.maxLayoutSize` properties. It allows the same API to take in both fixed sizes, as well as relative ones.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
// Dimension type "Auto" indicates that the layout element may 
// be resolved in whatever way makes most sense given the circumstances
ASDimension width = ASDimensionMake(ASDimensionUnitAuto, 0);  
ASDimension height = ASDimensionMake(@"50%");

layoutElement.style.preferredLayoutSize = ASLayoutSizeMake(width, height);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

<br>
If you do not need relative values, you can set the layout element's `.preferredSize`, `.minSize` and `.maxSize` properties. The properties take regular `CGSize` values. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
layoutElement.style.preferredSize = CGSizeMake(30, 160);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

<br>
Most of the time, you won't want to constrain both width and height. In these cases, you can individually set a layout element's size properties using `ASDimension` values.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
layoutElement.style.width     = ASDimensionMake(@"50%");
layoutElement.style.minWidth  = ASDimensionMake(@"50%");
layoutElement.style.maxWidth  = ASDimensionMake(@"50%");

layoutElement.style.height    = ASDimensionMake(@"50%");
layoutElement.style.minHeight = ASDimensionMake(@"50%");
layoutElement.style.maxHeight = ASDimensionMake(@"50%");
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Size Range (`ASSizeRange`)

`UIKit` doesn't provide a structure to bundle a minimum and maximum `CGSize`. So, `ASSizeRange` was created to support **a minimum and maximum CGSize pair**. 

`ASSizeRange` is used mostly in the internals of the layout API. However, the `constrainedSize` value passed as an input to `layoutSpecThatFits:` is an `ASSizeRange`.  
   
<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

<br>
The `constrainedSize` passed to an `ASDisplayNode` subclass' `layoutSpecThatFits:` method is the minimum and maximum sizes that the node should fit in. The minimum and maximum `CGSize`s contained in `constrainedSize` can be used to size the node's layout elements.
