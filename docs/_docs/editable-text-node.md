---
title: ASEditableTextNode
layout: docs
permalink: /docs/editable-text-node.html
prevPage: scroll-node.html
nextPage: multiplex-image-node.html
---

`ASEditableTextNode` is available to be used anywhere you'd normally use a `UITextView` or `UITextField`.  Under the hood, it uses a specialized `UITextView` as its backing view.  You can access and configure this view directly any time after the node has loaded, as long as you do it on the main thread.  

It's also important to note that this node does not support <a href = "/docs/layer-backing.html">layer backing</a> due to the fact that it supports user interaction.

### Basic Usage

Using an editable text node as a text input is easy.  If you want it to have text by default, you can assign an attributed string to the `attributedText` property.  

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
ASEditableTextNode *editableTextNode = [[ASEditableTextNode alloc] init];

editableTextNode.attributedText = [[NSAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet."];
editableTextNode.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
</pre>

<pre lang="swift" class = "swiftCode hidden">
let editableTextNode = ASEditableTextNode()

editableTextNode.attributedText = NSAttributedString(string: "Lorem ipsum dolor sit amet.")
editableTextNode.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
</pre>
</div>
</div>

### Placeholder Text

If you want to display a text box with a placeholder that disappears after a user starts typing, just assign an attributed string to the `attributedPlaceholderText` property.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
editableTextNode.attributedPlaceholderText = [[NSAttributedString alloc] initWithString:@"Type something here..."];
</pre>

<pre lang="swift" class = "swiftCode hidden">
editableTextNode.attributedPlaceholderText = NSAttributedString(string: "Type something here...")
</pre>
</div>
</div>

The property `isDisplayingPlaceholder` will initially return `YES`, but will toggle to `NO` any time the `attributedText` property is set to a non-empty string.

### Typing Attributes

To set up the style of the text your user will type into this text field, you can set the `typingAttributes`.


<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
editableTextNode.typingAttributes = @{NSForegroundColorAttributeName: [UIColor blueColor], 
                                      NSBackgroundColorAttributeName: [UIColor redColor]};
</pre>

<pre lang="swift" class = "swiftCode hidden">
editableTextNode.typingAttributes = [NSForegroundColorAttributeName: UIColor.blueColor(), 
                                      NSBackgroundColorAttributeName: UIColor.redColor()]
</pre>
</div>
</div>


### ASEditableTextNode Delegate

In order to respond to events associated with an editable text node, you can use any of the following delegate methods:


--  Indicates to the delegate that the text node began editing.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)editableTextNodeDidBeginEditing:(ASEditableTextNode *)editableTextNode;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional public func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode)
</pre>
</div>
</div>

--  Asks the delegate whether the specified text should be replaced in the editable text node.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (BOOL)editableTextNode:(ASEditableTextNode *)editableTextNode shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional public func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
</pre>
</div>
</div>

--  Indicates to the delegate that the text node's selection has changed.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)editableTextNodeDidChangeSelection:(ASEditableTextNode *)editableTextNode fromSelectedRange:(NSRange)fromSelectedRange toSelectedRange:(NSRange)toSelectedRange dueToEditing:(BOOL)dueToEditing;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional public func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool)
</pre>
</div>
</div>

--  Indicates to the delegate that the text node's text was updated.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)editableTextNodeDidUpdateText:(ASEditableTextNode *)editableTextNode;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional public func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode)
</pre>
</div>
</div>

--  Indicates to the delegate that teh text node has finished editing.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (void)editableTextNodeDidFinishEditing:(ASEditableTextNode *)editableTextNode;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional public func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode)
</pre>
</div>
</div>

