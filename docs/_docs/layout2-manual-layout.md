---
title: Manual Layout
layout: docs
permalink: /docs/layout2-manual-layout.html
---

## Manual Layout
After diving in to the automatic way for layout in ASDK there is still the _old_ way to layout manually available. For the sake of completness here is a short description how to accomplish that within ASDK.

### Manual Layout UIKit

Sizing and layout of custom view hierarchies are typically done all at once on the main thread.  For example, a custom UIView that minimally encloses a text view and an image view might look like this:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (CGSize)sizeThatFits:(CGSize)size
{
  // size the image
  CGSize imageSize = [_imageView sizeThatFits:size];

  // size the text view
  CGSize maxTextSize = CGSizeMake(size.width - imageSize.width, size.height);
  CGSize textSize = [_textView sizeThatFits:maxTextSize];

  // make sure everything fits
  CGFloat minHeight = MAX(imageSize.height, textSize.height);
  return CGSizeMake(size.width, minHeight);
}

- (void)layoutSubviews
{
  CGSize size = self.bounds.size; // convenience

  // size and layout the image
  CGSize imageSize = [_imageView sizeThatFits:size];
  _imageView.frame = CGRectMake(size.width - imageSize.width, 0.0f,
                                imageSize.width, imageSize.height);

  // size and layout the text view
  CGSize maxTextSize = CGSizeMake(size.width - imageSize.width, size.height);
  CGSize textSize = [_textView sizeThatFits:maxTextSize];
  _textView.frame = (CGRect){ CGPointZero, textSize };
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

This isn't ideal.  We're sizing our subviews twice &mdash; once to figure out how big our view needs to be and once when laying it out &mdash; and while our layout arithmetic is cheap and quick, we're also blocking the main thread on expensive text sizing.

We could improve the situation by manually cacheing our subviews' sizes, but that solution comes with its own set of problems.  Just adding `_imageSize` and `_textSize` ivars wouldn't be enough:  for example, if the text were to change, we'd need to recompute its size.  The boilerplate would quickly become untenable.

Further, even with a cache, we'll still be blocking the main thread on sizing *sometimes*.  We could try to shift sizing to a background thread with `dispatch_async()`, but even if our own code is thread-safe, UIView methods are documented to [only work on the main thread](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/index.html):

> Manipulations to your application’s user interface must occur on the main
> thread. Thus, you should always call the methods of the UIView class from
> code running in the main thread of your application. The only time this may
> not be strictly necessary is when creating the view object itself but all
> other manipulations should occur on the main thread.

This is a pretty deep rabbit hole.  We could attempt to work around the fact that UILabels and UITextViews cannot safely be sized on background threads by manually creating a TextKit stack and sizing the text ourselves... but that's a laborious duplication of work.  Further, if UITextView's layout behaviour changes in an iOS update, our sizing code will break.  (And did we mention that TextKit isn't thread-safe either?)

### Manual Layout ASDK

Manual layout within ASDK are realized within two methods:

#### `calculateSizeThatFits` and `layout`

Within `calculateSizeThatFits:` you should provide a intrinsic content size for the node based on the given `constrainedSize`. This method is called on a background thread so perform expensive sizing operations within it.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- [ASDisplayNode calculateSizeThatFits:]
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

After measurement and layout pass happens further layout can be done in `layout`. This method is called on the main thread. In there, layout operations can be done for nodes that are not playing within the automatic layout system and are referenced within `layoutSpecThatFits:`.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- [ASDisplayNode layout]
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

#### Example
Our custom node looks like this:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
#import <AsyncDisplayKit/AsyncDisplayKit+Subclasses.h>

...

// perform expensive sizing operations on a background thread
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  // size the image
  CGSize imageSize = [_imageNode layoutThatFits:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;

  // size the text node
  CGSize maxTextSize = CGSizeMake(constrainedSize.width - imageSize.width,
                                  constrainedSize.height);

  CGSize textSize = [_textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, maxTextSize)].size;

  // make sure everything fits
  CGFloat minHeight = MAX(imageSize.height, textSize.height);
  return CGSizeMake(constrainedSize.width, minHeight);
}

// do as little work as possible in main-thread layout
- (void)layout
{
  // layout the image using its cached size
  CGSize imageSize = _imageNode.calculatedSize;
  _imageNode.frame = CGRectMake(self.bounds.size.width - imageSize.width, 0.0f,
                                imageSize.width, imageSize.height);

  // layout the text view using its cached size
  CGSize textSize = _textNode.calculatedSize;
  _textNode.frame = (CGRect){ CGPointZero, textSize };
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

`ASImageNode` and `ASTextNode`, like the rest of AsyncDisplayKit, are thread-safe, so we can size them on background threads.  The `-layoutThatFits:` method is like `-sizeThatFits:`, but with side effects:  it caches the (`calculatedSize`) for quick access later on &mdash; like in our now-snappy `-layout` implementation.

As you can see, node hierarchies are sized and laid out in much the same way as their view counterparts.  Manually layed out nodes do need to be written with a few things in mind:

* Nodes must recursively measure all of their subnodes in their `-calculateSizeThatFits:` implementations.  Note that the `-layoutThatFits:` machinery will only call `-calculateSizeThatFits:` if a new measurement pass is needed (e.g., if the constrained size has changed) and `layoutSpecThatFits:` is *not* implemented.

* Nodes should perform any other expensive pre-layout calculations in `-calculateSizeThatFits:`, caching useful intermediate results in ivars as appropriate.

* Nodes should call `[self invalidateCalculatedSize]` when necessary.  For example, `ASTextNode` invalidates its calculated size when its `attributedString` property is changed.

As already mentioned, automatic layout is preferred over manual layout and should be the way to go in most cases.