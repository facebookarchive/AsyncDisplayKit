---
layout: docs
title: Asynchronous display
permalink: /guide/3/
prev: guide/2/
next: guide/4/
---

## Realistic placeholders

Nodes need to complete both a *measurement pass* and a *display pass* before
they're fully rendered.  It's possible to force either step to happen
synchronously: call `-measure:` in `-layoutSubviews` to perform sizing on the
main thread, or set a node's `displaysAsynchronously` flag to NO to disable
ASDK's async display machinery.  (AsyncDisplayKit can still improve your app's
performance even when rendering fully synchronously &mdash; more on that
later!)

The recommended way to use ASDK is to only add nodes to your view hierarchy
once they've been sized.  This avoids unsightly layout changes as the
measurement pass completes, but if you enable asynchronous display, it will
always be possible for a node to appear onscreen before its content has fully
rendered.  We'll discuss techniques to minimise this shortly, but you should
take it into account and include *realistic placeholders* in your app designs.

Once its measurement pass has completed, a node can accurately place all of its
subnodes onscreen &mdash; they'll just be blank.  The easiest way to make a
realistic placeholder is to set static background colours on your subnodes.
This effect looks better than generic placeholder images because it varies
based on the content being loaded, and it works particularly well for opaque
images.  You can also create visually-appealing placeholder nodes, like the
shimmery lines representing text in Paper as its stories are loaded, and swap
them out with your content nodes once they've finished displaying.

## Working range

So far, we've only discussed asynchronous sizing:  toss a "create a node
hierarchy and measure it" block onto a background thread, then trampoline to
the main thread to add it to the view hierarchy when that's done.  Ideally, as
much content as possible should be fully-rendered and ready to go as soon as
the user scrolls to it.  This requires triggering display passes in advance.

If your app's content is in a scroll view or can be paged through, like
Instagram's main feed or Paper's story strip, the solution is a *working
range*.  A working range controller tracks the *visible range*, the subset of
content that's currently visible onscreen, and enqueues asynchronous rendering
for the next few screenfuls of content.  As the user scrolls, a screenful or
two of previous content is preserved; the rest is cleared to conserve memory.
If she starts scrolling in the other direction, the working range trashes its
render queue and starts pre-rendering in the new direction of scroll &mdash;
and because of the buffer of previous content, this entire process will
typically be invisible.

AsyncDisplayKit includes a generic working range controller,
`ASRangeController`.  Its working range size can be tuned depending on your
app:  if your nodes are simple, even an iPhone 4 can maintain a substantial
working range, but heavyweight nodes like Facebook stories are expensive and
need to be pruned quickly.

```objective-c
ASRangeController *rangeController = [[ASRangeController alloc] init];
rangeController.tuningParameters = (ASRangeTuningParameters){
  .leadingBufferScreenfuls = 2.0f; // two screenfuls in the direction of scroll
  .trailingBufferScreenfuls = 0.5f; // one-half screenful in the other direction
};
```

If you use a working range, you should profile your app and consider tuning it
differently on a per-device basis.  iPhone 4 has 512MB of RAM and a single-core
A4 chipset, while iPhone 6 has 1GB of RAM and the orders-of-magnitude-faster
multicore A8 &mdash; and if your app supports iOS 7, it will be used on both.

## ASTableView

ASRangeController manages working ranges, but doesn't actually display content.
If your content is currently rendered in a UITableView, you can convert it to
use `ASTableView` and custom nodes &mdash; just subclass `ASCellNode` instead
of ASDisplayNode.  ASTableView is a UITableView subclass that integrates
node-based cells and a working range.

ASTableView doesn't let cells onscreen until their underlying nodes have been
sized, and as such can fully benefit from realistic placeholders.  Its API is
very similar to UITableView (see the
[Kittens](https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens)
sample project for an example), with some key changes:

*  Rather than  setting the table view's `.delegate` and `.dataSource`, you set
   its `.asyncDelegate` and `.asyncDataSource`.  See
   [ASTableView.h](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASTableView.h)
   for how its delegate and data source protocols differ from UITableView's.

*  Instead of implementing `-tableView:cellForRowAtIndexPath:`, your data
   source must implement `-tableView:nodeForRowAtIndexPath:`.  This method must
   be thread-safe and should not implement reuse.  Unlike the UITableView
   version, it won't be called when the row is about to display.

*  `-tableView:heightForRowAtIndexPath:` has been removed &mdash; ASTableView
   lets your cell nodes size themselves.  This means you no longer have to
   manually duplicate or factor out layout and sizing logic for
   dynamically-sized UITableViewCells!

Next up, how to get the most out of ASDK in your app.
