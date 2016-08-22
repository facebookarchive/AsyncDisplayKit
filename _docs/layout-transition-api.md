---
title: Layout Transition API
layout: docs
permalink: /docs/layout-transition-api.html
prevPage: batch-fetching-api.html
nextPage: hit-test-slop.html
---

The Layout Transition API was designed to make all animations with AsyncDisplayKit easy - even transforming an entire set of views into a completely different set of views!

With this system, you simply specify the desired layout and AsyncDisplayKit will do the work to figure out differences from the current layout. It will automatically add new elements, remove unneeded elements after the transiton, and update the position of any existing elements. 

There are also easy to use APIs that allow you to fully customize the starting position of newly introduced elements, as well as the ending position of removed elements. 

<div class = "note">
Use of <a href="implicit-hierarchy-mgmt.html">Implicit Hierarchy Management</a> is required to use the Layout Transition API.
</div>

## Animating between Layouts
<br>
The layout Transition API makes it easy to animate between a node's generated layouts in response to some internal state change in a node.

Imagine you wanted to implement this sign up form and animate in the new field when tapping the next button:

![Imgur](http://i.imgur.com/Dsf1R72.gif)

A standard way to implement this would be to create a container node called `SignupNode` that includes two editable text field nodes and a button node as subnodes. We'll include a property on the SignupNode called `fieldState` that will be used to select which editable text field node to show when the node calculates its layout. 

The internal layout spec of the `SignupNode` container would look something like this:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  FieldNode *field;
  if (self.fieldState == SignupNodeName) {
    field = self.nameField;
  } else {
    field = self.ageField;
  }

  ASStackLayoutSpec *stack = [[ASStackLayoutSpec alloc] init];
  [stack setChildren:@[field, self.buttonNode]];

  UIEdgeInsets insets = UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0);
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:stack];
}
</pre>
</div>
</div>

To trigger a transition from the `nameField` to the `ageField` in this example, we'll update the SignupNode's .fieldState property and begin the transition with `transitionLayoutWithAnimation:`. 

This method will invalidate the current calculated layout and recompute a new layout with the `ageField` now in the stack.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
self.signupNode.fieldState = SignupNodeAge;

[self.signupNode transitionLayoutWithAnimation:YES];
</pre>
</div>
</div>

In the default implementation of this API, the layout will recalculate the new layout and use its sublayouts to size and position the SignupNode's subnodes without animation. Future versions of this API will likely include a default animation between layouts and we're open to feedback on what you'd like to see here. However, we'll need to implement a custom animation block to handle the signup form case.

The example below represents an override of `animateLayoutTransition:` in the SignupNode. 

This method is called after the new layout has been calculated via `transitionLayoutWithAnimation:` and in the implementation we'll perform a specific animation based upon the fieldState property that was set before the animation was triggered. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  if (self.fieldState == SignupNodeName) {
    CGRect initialNameFrame = [context initialFrameForNode:self.ageField];
    initialNameFrame.origin.x += initialNameFrame.size.width;
    self.nameField.frame = initialNameFrame;
    self.nameField.alpha = 0.0;
    CGRect finalEmailFrame = [context finalFrameForNode:self.nameField];
    finalEmailFrame.origin.x -= finalEmailFrame.size.width;
    [UIView animateWithDuration:0.4 animations:^{
      self.nameField.frame = [context finalFrameForNode:self.nameField];
      self.nameField.alpha = 1.0;
      self.ageField.frame = finalEmailFrame;
      self.ageField.alpha = 0.0;
    } completion:^(BOOL finished) {
      [context completeTransition:finished];
    }];
  } else {
    CGRect initialAgeFrame = [context initialFrameForNode:self.nameField];
    initialAgeFrame.origin.x += initialAgeFrame.size.width;
    self.ageField.frame = initialAgeFrame;
    self.ageField.alpha = 0.0;
    CGRect finalNameFrame = [context finalFrameForNode:self.ageField];
    finalNameFrame.origin.x -= finalNameFrame.size.width;
    [UIView animateWithDuration:0.4 animations:^{
      self.ageField.frame = [context finalFrameForNode:self.ageField];
      self.ageField.alpha = 1.0;
      self.nameField.frame = finalNameFrame;
      self.nameField.alpha = 0.0;
    } completion:^(BOOL finished) {
      [context completeTransition:finished];
    }];
  }
}
</pre>
</div>
</div>


The passed <a href="https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASContextTransitioning.h"><code>ASContextTransitioning</code></a> context object in this method contains relevant information to help you determine the state of the nodes before and after the transition. It includes getters into old and new constrained sizes, inserted and removed nodes, and even the raw old and new `ASLayout` objects. In the `SignupNode` example, we're using it to determine the frame for each of the fields and animate them in an out of place.

It is imperative to call `completeTransition:` on the context object once your animation has finished, as it will perform the necessary internal steps for the newly calculated layout to become the current `calculatedLayout`.

Note that there hasn't been a use of `addSubnode:` or `removeFromSupernode` during the transition. AsyncDisplayKit's layout transition API analyzes the differences in the node hierarchy between the old and new layout, implicitly performing node insertions and removals via <a href="implicit-hierarchy-management.html">Implicit Hierarchy Management</a>. 

Nodes are inserted before your implementation of `animateLayoutTransition:` is called and this is a good place to manually manage the hierarchy before you begin the animation. Removals are preformed in `didCompleteLayoutTransition:` after you call `completeTransition:` on the context object. If you need to manually perform deletions, override `didCompleteLayoutTransition:` and perform your custom operations. Note that this will override the default behavior and it is recommended to either call `super` or walk through the `removedSubnodes` getter in the context object to perform the cleanup.

Passing NO to `transitionLayoutWithAnimation:` will still run through your `animateLayoutTransition:` and `didCompleteLayoutTransition:` implementations with the `[context isAnimated]` property set to NO. It is your choice on how to handle this case — if at all. An easy way to provide a default implementation this is to call super:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  if ([context isAnimated]) {
    // perform animation
  } else {
    [super animateLayoutTransition:context];
  }
}
</pre>
</div>
</div>

## Animating constrainedSize Changes
<br>
There will be times you'll simply want to respond to bounds changes to your node and animate the recalculation of its layout. To handle this case, call `transitionLayoutWithSizeRange:animated:` on your node. 

This method is similar to `transitionLayoutWithAnimation:`, but will not trigger an animation if the passed `ASSizeRange` is equal to the current `constrainedSizeForCalculatedLayout` value. This is great for responding to rotation events and view controller size changes:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    [self.node transitionLayoutWithSizeRange:ASSizeRangeMake(size, size) animated:YES];
  } completion:nil];
}
</pre>
</div>
</div>
