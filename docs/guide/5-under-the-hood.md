---
layout: docs
title: Under the hood
permalink: /guide/5/
prev: guide/4/
---

## Node architecture

*(Skip to the next section if you're not interested in AsyncDisplayKit implementation details.)*

We've described nodes as an abstraction over views and layers, and shown how to
interact with the underlying UIViews and CALayers when necessary.  Nodes don't
wrap or vend their UIKit counterparts, though &mdash; an ASImageNode's `.view`
is not a UIImageView!  So how do nodes work?

**NOTE:**  Classes whose names begin with `_` are private.  Don't use them
directly!

Creating a node doesn't create its underlying view-layer pair.  This is why you
can create nodes cheaply and on background threads.  When you use a UIView or
CALayer property on a node, you're actually interacting with a proxy object,
[`_ASPendingState`](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/Private/_ASPendingState.h),
that's preconfigured to match UIView and CALayer defaults.

The first access to a node's `.view` or `.layer` property causes both to be
initialised and configured with the node's current state.  If it has subnodes,
they are recursively loaded as well.  Once a node has been loaded, the proxy
object is destroyed and the node becomes main-thread-affined &mdash; its
properties will update the underlying view directly.  (Layer-backed nodes do
the same, not loading views.)

Nodes are powered by
[`_ASDisplayLayer`](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/Details/_ASDisplayLayer.h)
and
[`_ASDisplayView`](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/Details/_ASDisplayView.h).
These are lightweight to create and add to their respective hierarchies, and
provide integration points that allow nodes to act as full-fledged views or
layers.  It's possible to create nodes that are backed by custom view or layer
classes, but doing so is strongly discouraged as it disables the majority of
ASDK's functionality.  

When Core Animation asks an `_ASDisplayLayer` to draw itself, the request is
forwarded to its node.  Unless asynchronous display has been disabled, the
actual draw call won't happen immediately or on the main thread.  Instead, a
display block will be added to a background queue.  These blocks are executed
in parallel, but you can enable `ASDISPLAYNODE_DELAY_DISPLAY` in
[`ASDisplayNode(AsyncDisplay)`](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/Private/ASDisplayNode%2BAsyncDisplay.mm)
to serialise the render system for debugging.

Common UIView subclass hooks are forwarded from `_ASDisplayView` to its
underlying node, including touch handling, hit-testing, and gesture recogniser
delegate calls.  Because an `_ASDisplayView`'s layer is an `_ASDisplayLayer`,
view-backed nodes also participate in asynchronous display.

## In practice

What does this mean for your custom nodes?

You can implement methods like `-touchesBegan:withEvent:` /
`touchesMoved:withEvent:` / `touchesEnded:withEvent:` /
`touchesCancelled:withEvent:` in your nodes exactly as you would in a UIView
subclass.  If you find you need a subclass hook that hasn't already been
provided, please file an issue on GitHub &mdash; or add it yourself and submit a
pull request!

If you need to interact or configure your node's underlying view or layer,
don't do so in `-init`.  Instead, override `-didLoad` and check if you're
layer-backed:

```objective-c
- (void)didLoad
{
  [super didLoad];
 
  // add a gesture recogniser, if we have a view to add it to
  if (!self.layerBacked) {
    _gestureRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(_tap:)];
    [self.view addGestureRecognizer:_gestureRecogniser];
  }
}
```

## *fin.*

Thanks for reading!  If you have any questions, please file a GitHub issue or
post in the [Facebook group](https://www.facebook.com/groups/551597518288687).
We'd love to hear from you.
