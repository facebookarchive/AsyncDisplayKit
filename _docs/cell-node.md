---
title: ASCellNode
layout: docs
permalink: /docs/cell-node.html
next: text-cell-node.html
---

ASCellNode is maybe the most commonly <a href = "subclassing.html">subclassed node</a>.  It can be used as the cell for both ASTableNodes and ASCollectionNodes.  

That being said, subclassing it is largely the same as subclassing a regular ASDisplayNode.  Most importantly, you'll write an -init method, a -layoutSpecThatFits: method for measurement and layout, and, if necessary, a -didLoad method for adding extra gesture recognizers and a -layout method for any extra layout needs.

If you don't feel like subclassing you're also free to use the `-initWithView:` or `-initWithViewController:` methods to return nodes with backing views created from an existing view or view controller you already have.

