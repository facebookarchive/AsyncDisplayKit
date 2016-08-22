---
title: Upgrading to 2.0 <b><i>(New)</i></b>
layout: docs
permalink: /docs/upgrading.html
prevPage: installation.html
nextPage: image-modification-block.html
---

AsyncDisplayKit **2.0 Beta** is (almost) here! Here's a brief summary of the changes on [master](https://github.com/facebook/AsyncDisplayKit) as of today:

**Find & replace API naming improvements:**

- `.usesImplicitHierarchyManagement` renamed to `.automaticallyManagesSubnodes`
- `ASRelativeDimensionTypePercent` and associated functions renamed to use `Fraction` to be consistent with Apple terminology.

**Make sure to check:**

- `constrainedSizeForNodeAtIndexPath:` moved from the `.dataSource` to the `.delegate` to be consistent with UIKit definitions of the roles. **Note:** Make sure that you provide a delegate for any `ASTableNode`, `ASCollectionNode` or `ASPagerNodes` that use this method. 

**Good to know:**

- Layout Transition API (`transitionLayoutWithDuration:`) has been moved out of Beta

The majority of the remaining (unmerged) changes will be in the Layout API. 