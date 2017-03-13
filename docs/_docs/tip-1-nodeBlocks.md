---
title: Prefer `nodeBlocks` for Performance
layout: docs
permalink: /docs/tip-1-nodeBlocks.html
---

AsyncDisplayKit’s `ASCollectionNode` replaces `UICollectionView`’s required method

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
collectionNode:cellForItemAtIndexPath:
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

<br>
with your choice of **one** of the two following methods 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
// called on main thread, ASCellNode initialized on main and then returned 
collectionNode:nodeForItemAtIndexPath: 

OR

// called on main thread, ASCellNodeBlock returned, then
// ASCellNode initialized in background when block is called by system
collectionNode:nodeBlockForItemAtIndexPath: 
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

<br>
`ASTableNode` has the same options: 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
`tableNode:nodeForRow:`
`tableNode:nodeBlockforRow:`    // preferred
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

`ASPagerNode` does as well: 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
`pagerNode:nodeAtIndex:`
`pagerNode:nodeBlockAtIndex:`   // preferred
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>


We reccommend that you use nodeBlocks. Using the nodeBlock method allows table and collections to request blocks for each cell node, and execute them **concurrently** across multiple threads, which allows us to **parallelize the allocation costs** (in addition to layout measurement). 

This leaves our main thread more free to handle touch events and other time sensitive work, keeping our user's taps happy and responsive. 

### Access your data source outside of the nodeBlock

Because nodeBlocks are executed on a background thread, it is very important they be thread-safe. 

The most important aspect to consider is accessing properties on self that may change, such as an array of data models. This can be handled safely by ensuring that any immutable state is collected above the node block.

**Using the indexPath parameter to access a mutable collection inside the node block is not safe.** This is because by the time the block runs, the dataSource may have changed. 

Here's an example of a simple nodeBlock:

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // data model is accessed outside of the node block
    Board *board = [self.boards objectAtIndex:indexPath.item];
    return ^{
        BoardScrubberCellNode *node = [[BoardScrubberCellNode alloc] initWithBoard:board];
        return node;
    };
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

<br>
Note that it is okay to use the indexPath if it is used strictly for its integer values and not to index a value from a mutable data source. 

## Do not return nil from a nodeBlock

Just as when UIKit requests a cell, returning `nil` will crash the app, so it is important to ensure a valid ASCellNode is returned for either the node or nodeBlock method. Your code should ensure that at least a blank ASCellNode is returned, but ideally the number of items reported to the collection would prevent the method from being called when there is no data to display. 