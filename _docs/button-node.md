---
title: ASButtonNode
layout: docs
permalink: /docs/button-node.html
prevPage: control-node.html
nextPage: text-node.html
---

### Basic Usage

`ASButtonNode` subclasses `ASControlNode` in the same way `UIButton` subclasses `UIControl`. In contrast, being able to layer back the subnodes of every button can significantly lighten main thread impact relative to UIButton.

### Control State

If you've used `-setTitle:forControlState:` then you already know how to set up an ASButtonNode.  The ASButtonNode version adds in a few parameters for conveniently setting attributes.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
[buttonNode setTitle:@"Button Title Normal" withFont:nil withColor:[UIColor blueColor] forState:ASControlStateNormal];
</pre>
<pre lang="swift" class = "swiftCode hidden">
button.setTitle("Button Title Normal", withFont: nil, withColor: UIColor.blueColor(), forState: .Normal)
</pre>
</div>
</div>

If you need even more control, you can also opt to use the attributed string version directly:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
[self.buttonNode setAttributedTitle:attributedTitle forState:ASControlStateNormal];
</pre>
<pre lang="swift" class = "swiftCode hidden">
buttonNode.setAttributedTitle(attributedTitle forState:ASControlStateNormal)
</pre>
</div>
</div>

### Target-Action Pairs

Again, analagous to UIKit, you can add sets of target-action pairs to respond to various events.  

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
[buttonNode addTarget:self action:@selector(buttonPressed:) forControlEvents:ASControlNodeEventTouchUpInside];
</pre>
<pre lang="swift" class = "swiftCode hidden">
button.addTarget(self, action: #selector(buttonPressed(_:)), forControlEvents: .TouchUpInside)
</pre>
</div>
</div>

### Content Alignment

ASButtonNode offers both `contentVerticalAlignment` and `contentHorizontalAlignment` properties.  This allows you to easily set the alignment of the titleLabel or image you're using for your button.  

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
self.buttonNode.contentVerticalAlignment = ASVerticalAlignmentTop;
self.buttonNode.contentHorizontalAlignment = ASHorizontalAlignmentMiddle;
</pre>
<pre lang="swift" class = "swiftCode hidden">
buttonNode.contentVerticalAlignment = .Top
buttonNode.contentHorizontalAlignment = .Middle
</pre>
</div>
</div>

<div class = "note"><strong>Note:</strong> At the moment, this property will not work if you aren't using <em>-layoutSpecThatFits:</em>.
</div>

### Gotchas

There are a few things that might trip up someone new to the framework.

##### View Hierarchies
Let's say you want to add an ASButtonNode to the view of one of your existing view controllers.  The first thing you'll notice is that setting a title for a control state doesn't seem to make your title appear.  You can fix this by calling `-measure:` on the button which will cause its title label to be measured and laid out.

The next thing you'll notice is that, if you set titles of various lengths for different control states, the button will dynamically grow and shrink as the title changes.  This is because changing the title causes `-setNeedsLayout` to be called on the button.  Within a node hierarchy, this makes sense, and will work as expected.

Long story short, use an ASViewController.

##### Selected State

If you want your button to change to a "selected" state after being tapped, you'll need to do that manually.

