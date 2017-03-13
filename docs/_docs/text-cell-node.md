---
title: ASTextCellNode
layout: docs
permalink: /docs/text-cell-node.html
prevPage: cell-node.html
nextPage: control-node.html
---

ASTextCellNode is a simple ASCellNode subclass you can use when all you need is a cell with styled text. 

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
ASTextCellNode *textCell = [[ASTextCellNode alloc]
            initWithAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"SomeFont" size:16.0]} 												  insets:UIEdgeInsetsMake(8, 16, 8, 16)];
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
let textCellNode = ASTextCellNode(attributes: [NSFontAttributeName: UIFont(name: "SomeFont", size: 16.0)], 
                        		      insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
</pre>
</div>
</div>

The text can be configured on initialization or after the fact.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
ASTextCellNode *textCell = [[ASTextCellNode alloc] init];

textCellNode.text         = @"Some dang ol' text";
textCellNode.attributes   = @{NSFontAttributeName: [UIFont fontWithName:@"SomeFont" size:16.0]};
textCellNode.insets       = UIEdgeInsetsMake(8, 16, 8, 16);
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
let textCellNode = ASTextCellNode()

textCellNode.text         = "Some dang ol' text"
textCellNode.attributes   = [NSFontAttributeName: UIFont(name: "SomeFont", size: 16.0)]
textCellNode.insets       = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
</pre>
</div>
</div>