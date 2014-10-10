---
layout: docs
title: Getting started
permalink: /guide/
next: guide/2/
---

## Concepts

AsyncDisplayKit's basic unit is the *node*.  ASDisplayNode is an abstraction
over UIView, which in turn is an abstraction over CALayer.  Unlike views, which
can only be used on the main thread, nodes are thread-safe:  you can
instantiate and configure entire hierarchies of them in parallel on background
threads.

To keep its user interface smooth and responsive, your app should render at 60
frames per second &mdash; the gold standard on iOS.  This means the main thread
has one-sixtieth of a second to push each frame.  That's 16 milliseconds to
execute all layout and drawing code!  And because of system overhead, your code
usually has less than ten milliseconds to run before it causes a frame drop.

AsyncDisplayKit lets you move image decoding, text sizing and rendering, and
other expensive UI operations off the main thread.  It has other tricks up its
sleeve too... but we'll get to that later.  :]

## Nodes as drop-in view replacements

If you're used to working with views, you already know how to use nodes.  The
node API is similar to UIView's, with some additional conveniences &mdash; for
example, you can access common CALayer properties directly.  To add a node to
an existing view or layer hierarchy, use its `node.view` or `node.layer`.

AsyncDisplayKit includes several powerful components:

*  *ASDisplayNode*.  Counterpart to UIView &mdash; subclass to make custom nodes.
*  *ASControlNode*.  Analogous to UIControl &mdash; subclass to make buttons.
*  *ASImageNode*.  Like UIImageView &mdash; decodes images asynchronously.
*  *ASTextNode*.  Like UITextView &mdash; built on TextKit with full-featured
   rich text support.
*  *ASTableView*.  UITableView subclass that supports nodes.

You can use these as drop-in replacements for their UIKit counterparts.  While
ASDK works most effectively with fully node-based hierarchies, even replacing
individual views with nodes can improve performance.

Let's look at an example.

We'll start out by using nodes synchronously on the main thread &mdash; the
same way you already use views.  This code is a familiar sight in custom view
controller `-loadView` implementations:

```objective-c
_imageView = [[UIImageView alloc] init];
_imageView.image = [UIImage imageNamed:@"hello"];
_imageView.frame = CGRectMake(10.0f, 10.0f, 40.0f, 40.0f);
[self.view addSubview:_imageView];
```

We can replace it with the following node-based code:

```objective-c
_imageNode = [[ASImageNode alloc] init];
_imageNode.backgroundColor = [UIColor lightGrayColor];
_imageNode.image = [UIImage imageNamed:@"hello"];
_imageNode.frame = CGRectMake(10.0f, 10.0f, 40.0f, 40.0f);
[self.view addSubview:_imageNode.view];
```

This doesn't take advantage of ASDK's asynchronous sizing and layout
functionality, but it's already an improvement.  The first block of code
synchronously decodes `hello.png` on the main thread; the second starts
decoding the image on a background thread, possibly on a different CPU core.

(Note that we're setting a placeholder background colour on the node, "holding
its place" onscreen until the real content appears.  This works well with
images but less so with text &mdash; people expect text to appear instantly,
with images loading in after a slight delay.  We'll discuss techniques to
improve this later on.)

## Button nodes

ASImageNode and ASTextNode both inherit from ASControlNode, so you can use them
as buttons.  Let's say we're making a music player and we want to add a
(non-skeuomorphic, iOS 7-style) shuffle button:

[![shuffle]({{ site.baseurl }}/assets/guide/1-shuffle-crop.png)]({{ site.baseurl }}/assets/guide/1-shuffle.png)

Our view controller will look something like this:

```objective-c
- (void)viewDidLoad
{
  [super viewDidLoad];

  // attribute a string
  NSDictionary *attrs = @{
                          NSFontAttributeName: [UIFont systemFontOfSize:12.0f],
                          NSForegroundColorAttributeName: [UIColor redColor],
                          };
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:@"shuffle"
                                                               attributes:attrs];

  // create the node
  _shuffleNode = [[ASTextNode alloc] init];
  _shuffleNode.attributedString = string;

  // configure the button
  _shuffleNode.userInteractionEnabled = YES; // opt into touch handling
  [_shuffleNode addTarget:self
                   action:@selector(buttonTapped:)
         forControlEvents:ASControlNodeEventTouchUpInside];

  // size all the things
  CGRect b = self.view.bounds; // convenience
  CGSize size = [_shuffleNode measure:CGSizeMake(b.size.width, FLT_MAX)];
  CGPoint origin = CGPointMake(roundf( (b.size.width - size.width) / 2.0f ),
                               roundf( (b.size.height - size.height) / 2.0f ));
  _shuffleNode.frame = (CGRect){ origin, size };

  // add to our view
  [self.view addSubview:_shuffleNode.view];
}

- (void)buttonTapped:(id)sender
{
  NSLog(@"tapped!");
}
```

This works as you would expect.  Unfortunately, this button is only 14&frac12;
points tall &mdash; nowhere near the standard 44&times;44 minimum tap target
size &mdash; and it's very difficult to tap.  We could solve this by
subclassing the text node and overriding `-hitTest:withEvent:`.  We could even
force the text view to have a minimum height during layout.  But wouldn't it be
nice if there were a more elegant way?

```objective-c
  // size all the things
  /* ... */

  // make the tap target taller
  CGFloat extendY = roundf( (44.0f - size.height) / 2.0f );
  _shuffleNode.hitTestSlop = UIEdgeInsetsMake(-extendY, 0.0f, -extendY, 0.0f);
```

Et voilà!  *Hit-test slops* work on all nodes, and are a nice example of what
this new abstraction enables.

Next up, making your own nodes!
