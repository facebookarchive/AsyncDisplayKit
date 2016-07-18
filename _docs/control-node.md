---
title: ASControlNode
layout: docs
permalink: /docs/control-node.html
prevPage: cell-node.html
nextPage: button-node.html
---

ASControlNode is the ASDK equivalent to UIControl.  You don't create instances of ASControlNode directly.  Instead, you can use it as a subclassing point when creating controls of your own.  In fact, <a href = "/docs/text-node.html">ASTextNode</a>, <a href = "/docs/image-node.html">ASImageNode</a>, <href = "#">ASVideoNode</a> and <a href = "/docs/video-node.html">ASMapNode</a> are all subclasses of ASControlNode.

This fact is especially useful when it comes to image and text nodes.  Having the ability to add target-action pairs means that you can use any text or image node as a button without having to rely on creating gesture recognizers, as you would with text in UIKit, or creating extraneous views as you might when using UIButton.

### Control State

Like UIControl, ASControlNode has a state which defines its appearance and ability to support user interactions.  Its state can be one of any state defined by `ASControlState`.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
typedef NS_OPTIONS(NSUInteger, ASControlState) {
    ASControlStateNormal       = 0,
    ASControlStateHighlighted  = 1 << 0,  // used when isHighlighted is set
    ASControlStateDisabled     = 1 << 1,
    ASControlStateSelected     = 1 << 2,  // used when isSelected is set
    ...
};
  </pre>
</div>
</div>

### Target-Action Mechanism

Also similarly to UIControl, ASControlNode's have a set of events defined which you can react to by assigning a target-action pair.  

The available actions are: 
<div class = "highlight-group">
<span class="language-toggle"><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
typedef NS_OPTIONS(NSUInteger, ASControlNodeEvent)
{
  /** A touch-down event in the control node. */
  ASControlNodeEventTouchDown         = 1 << 0,
  /** A repeated touch-down event in the control node; for this event the value of the UITouch tapCount method is greater than one. */
  ASControlNodeEventTouchDownRepeat   = 1 << 1,
  /** An event where a finger is dragged inside the bounds of the control node. */
  ASControlNodeEventTouchDragInside   = 1 << 2,
  /** An event where a finger is dragged just outside the bounds of the control. */
  ASControlNodeEventTouchDragOutside  = 1 << 3,
  /** A touch-up event in the control node where the finger is inside the bounds of the node. */
  ASControlNodeEventTouchUpInside     = 1 << 4,
  /** A touch-up event in the control node where the finger is outside the bounds of the node. */
  ASControlNodeEventTouchUpOutside    = 1 << 5,
  /** A system event canceling the current touches for the control node. */
  ASControlNodeEventTouchCancel       = 1 << 6,
  /** All events, including system events. */
  ASControlNodeEventAllEvents         = 0xFFFFFFFF
};
</pre>
</div>
</div>

Assigning a target and action for these events is done with the same methods as a UIControl, namely using `–addTarget:action:forControlEvents:`.

### Hit Test Slop

While all node's have a `hitTestSlop` property, this is usually most useful when dealing with controls.  Instead of needing to make your control bigger, or needing to override -hitTest:withEvent: you can just assign a UIEdgeInsets to your control and its boundaries will be expanded accordingly.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
CGFloat horizontalDiff = (bounds.size.width - _playButton.bounds.size.width)/2;
CGFloat verticalDiff = (bounds.size.height - _playButton.bounds.size.height)/2;

_playButton.hitTestSlop = UIEdgeInsetsMake(-verticalDiff, -horizontalDiff, -verticalDiff, -horizontalDiff);
</pre>
<!-- <pre lang="swift" class = "swiftCode hidden">
let horizontalDiff: CGFloat = (bounds.size.width - playButton.bounds.size.width)/2.0
let verticalDiff: CGfloat   = (bounds.size.height - playButton.bounds.size.height)/2.0

playButton.hitTestSlop = UIEdgeInsets(top: -verticalDiff, left: -horizontalDiff, bottom: -verticalDiff, right: -horizontalDiff)
</pre> -->
</div>
</div>

Remember that, since the property is an inset, you'll need to use negative values in order to expand the size of your tappable region.

### Hit Test Visualization

The <a href = "/docs/debug-tool-hit-test-visualization.html">hit test visualization tool</a> is an option to enable highlighting of the tappable areas of your nodes.  To enable it, include `[ASControlNode setEnableHitTestDebug:YES]` in your app delegate in `-application:didFinishLaunchingWithOptions:`.
