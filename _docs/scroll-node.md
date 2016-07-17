---
title: ASScrollNode
layout: docs
permalink: /docs/scroll-node.html
prevPage: video-node.html
nextPage: automatic-layout-containers.html
---

`ASScrollNode` is literally a wrapped `UIScrollView`.

### Basic Usage

In case you're not familiar with scroll views, they are basically windows into content that would take up more space than can fit in that area.

Say you have a giant image, but you only want to take up 200x200 pts on the screen.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
UIImage *scrollNodeImage = [UIImage imageNamed:@"image"];
ASScrollNode *scrollNode = [[ASScrollNode alloc] init];

scrollNode.preferredFrameSize = CGSizeMake(200.0, 200.0);

UIScrollView *scrollNodeView = scrollNode.view;
[scrollNodeView addSubview:[[UIImageView alloc] initWithImage:scrollNodeImage]];
scrollNodeView.contentSize = scrollNodeImage.size;
</pre>
<pre lang="swift" class = "swiftCode hidden">
let scrollNodeImage = UIImage(named: "image")
let scrollNode = ASScrollNode()

scrollNode.preferredFrameSize = CGSize(width: 200.0, height: 200.0)

let scrollNodeView = scrollNode.view
scrollNodeView.addSubview(UIImageView(image: scrollNodeImage))
scrollNodeView.contentSize = scrollNodeImage.size
</pre>
</div>
</div>

As you can see, the scrollNode's underlying view is a `UIScrollView`.

