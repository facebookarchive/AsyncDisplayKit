---
layout: docs
title: Custom nodes
permalink: /guide/2/
prev: guide/
next: guide/3/
---

## View hierarchies

Sizing and layout of custom view hierarchies are typically done all at once on
the main thread.  For example, a custom UIView that minimally encloses a text
view and an image view might look like this:

```objective-c
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
```

This isn't ideal.  We're sizing our subviews twice &mdash; once to figure out
how big our view needs to be and once when laying it out &mdash; and while our
layout arithmetic is cheap and quick, we're also blocking the main thread on
expensive text sizing.

We could improve the situation by manually cacheing our subviews' sizes, but
that solution comes with its own set of problems.  Just adding `_imageSize` and
`_textSize` ivars wouldn't be enough:  for example, if the text were to change,
we'd need to recompute its size.  The boilerplate would quickly become
untenable.

Further, even with a cache, we'll still be blocking the main thread on sizing
*sometimes*.  We could try to shift sizing to a background thread with
`dispatch_async()`, but even if our own code is thread-safe, UIView methods are
documented to [only work on the main
thread](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/index.html):

> Manipulations to your application’s user interface must occur on the main
> thread. Thus, you should always call the methods of the UIView class from
> code running in the main thread of your application. The only time this may
> not be strictly necessary is when creating the view object itself but all
> other manipulations should occur on the main thread.

This is a pretty deep rabbit hole.  We could attempt to work around the fact
that UILabels and UITextViews cannot safely be sized on background threads by
manually creating a TextKit stack and sizing the text ourselves... but that's a
laborious duplication of work.  Further, if UITextView's layout behaviour
changes in an iOS update, our sizing code will break.  (And did we mention that
TextKit isn't thread-safe either?)

## Node hierarchies

Enter AsyncDisplayKit.  Our custom node looks like this:

```objective-c
#import <AsyncDisplayKit/AsyncDisplayKit+Subclasses.h>

...

// perform expensive sizing operations on a background thread
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  // size the image
  CGSize imageSize = [_imageNode measure:constrainedSize];

  // size the text node
  CGSize maxTextSize = CGSizeMake(constrainedSize.width - imageSize.width,
                                  constrainedSize.height);
  CGSize textSize = [_textNode measure:maxTextSize];

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
```

ASImageNode and ASTextNode, like the rest of AsyncDisplayKit, are thread-safe,
so we can size them on background threads.  The `-measure:` method is like
`-sizeThatFits:`, but with side effects:  it caches both the argument
(`constrainedSizeForCalculatedSize`) and the result (`calculatedSize`) for
quick access later on &mdash; like in our now-snappy `-layout` implementation.

As you can see, node hierarchies are sized and laid out in much the same way as
their view counterparts.  Custom nodes do need to be written with a few things
in mind:

*  Nodes must recursively measure all of their subnodes in their
   `-calculateSizeThatFits:` implementations.  Note that the `-measure:`
   machinery will only call `-calculateSizeThatFits:` if a new measurement pass
   is needed (e.g., if the constrained size has changed).

*  Nodes should perform any other expensive pre-layout calculations in
   `-calculateSizeThatFits:`, cacheing useful intermediate results in ivars as
   appropriate.

*  Nodes should call `[self invalidateCalculatedSize]` when necessary.  For
   example, ASTextNode invalidates its calculated size when its
   `attributedString` property is changed.

For more examples of custom sizing and layout, along with a demo of
ASTextNode's features, check out `BlurbNode` and `KittenNode` in the
[Kittens](https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens)
sample project.

## Custom drawing

To guarantee thread safety in its highly-concurrent drawing system, the node
drawing API diverges substantially from UIView's.  Instead of implementing
`-drawRect:`, you must:

1.  Define an internal "draw parameters" class for your custom node.  This
    class should be able to store any state your node needs to draw itself
    &mdash; it can be a plain old NSObject or even a dictionary.

2.  Return a configured instance of your draw parameters class in
    `-drawParametersForAsyncLayer:`.  This method will always be called on the
    main thread.

3.  Implement either `+drawRect:withParameters:isCancelled:isRasterizing:` or
    `+displayWithParameters:isCancelled:`.  Note that these are *class* methods
    that will not have access to your node's state &mdash; only the draw
    parameters object.  They can be called on any thread and must be
    thread-safe.

For example, this node will draw a rainbow:

```objective-c
@interface RainbowNode : ASDisplayNode
@end

@implementation RainbowNode

+ (void)drawRect:(CGRect)bounds
  withParameters:(id<NSObject>)parameters
     isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock
   isRasterizing:(BOOL)isRasterizing
{
  // clear the backing store, but only if we're not rasterising into another layer
  if (!isRasterizing) {
    [[UIColor whiteColor] set];
    UIRectFill(bounds);
  }

  // UIColor sadly lacks +indigoColor and +violetColor methods
  NSArray *colors = @[ [UIColor redColor],
                       [UIColor orangeColor],
                       [UIColor yellowColor],
                       [UIColor greenColor],
                       [UIColor blueColor],
                       [UIColor purpleColor] ];
  CGFloat stripeHeight = roundf(bounds.size.height / (float)colors.count);

  // draw the stripes
  for (UIColor *color in colors) {
    CGRect stripe = CGRectZero;
    CGRectDivide(bounds, &stripe, &bounds, stripeHeight, CGRectMinYEdge);
    [color set];
    UIRectFill(stripe);
  }
}

@end
```

This could easily be extended to support vertical rainbows too, by adding a
`vertical` property to the node, exporting it in
`-drawParametersForAsyncLayer:`, and referencing it in
`+drawRect:withParameters:isCancelled:isRasterizing:`. More-complex nodes can
be supported in much the same way.

For more on custom nodes, check out the [subclassing
header](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASDisplayNode%2BSubclasses.h)
or read on!
