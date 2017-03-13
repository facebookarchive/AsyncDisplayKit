---
title: Inversion
layout: docs
permalink: /docs/inversion.html
prevPage: automatic-subnode-mgmt.html
nextPage: image-modification-block.html
---

`ASTableNode` and `ASCollectionNode` have a `inverted` property of type `BOOL` that when set to `YES`, will automatically invert the content so that it's layed out bottom to top, that is the 'first' (indexPath 0, 0) node is at the bottom rather than the top as usual. <b>This is extremely covenient for chat/messaging apps, and with AsyncDisplayKit it only takes one property</b>.

When this is enabled, developers only have to take one more step to have full inversion support and that is to adjust the `contentInset` of their `ASTableNode` or `ASCollectionNode` like so:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
 CGFloat inset = [self topBarsHeight];
 self.tableNode.view.contentInset = UIEdgeInsetsMake(0, 0, inset, 0);
 self.tableNode.view.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, inset, 0);
  </pre>

  <pre lang="swift" class = "swiftCode hidden">

  </pre>
</div>
</div>

See the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/SocialAppLayout-Inverted">SocialAppLayout-Inverted</a> example project for more details.
