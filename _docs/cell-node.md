---
title: ASCellNode
layout: docs
permalink: /docs/cell-node.html
next: text-cell-node.html
---

ASCellNode is maybe the most commonly <a href = "subclassing.html">subclassed node</a>.  It can be used as the cell for both ASTableNodes and ASCollectionNodes.  

If you don't feel like subclassing you're also free to use the `-initWithView:` or `initWithViewController:` methods to return nodes with backing views created from an existing view or view controller you already have.