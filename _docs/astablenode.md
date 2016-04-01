---
title: ASTableNode
layout: docs
permalink: /docs/astablenode.html
---

ASRangeController manages working ranges, but doesn't actually display content. If your content is currently rendered in a UITableView, you can convert it to use ASTableNode and custom nodes — just subclass ASCellNode instead of ASDisplayNode. ASTableNode maintains a UITableView subclass that integrates node-based cells and a working range.

ASTableNode doesn't let cells onscreen until their underlying nodes have been sized, and as such can fully benefit from realistic placeholders. Its API is very similar to UITableView (see the Kittens sample project for an example), with some key changes:

Instead of implementing -tableView:cellForRowAtIndexPath:, your data source must implement -tableView:nodeForRowAtIndexPath:. This method must be thread-safe and should not implement reuse. Unlike the UITableView version, it won't be called when the row is about to display.

-tableView:heightForRowAtIndexPath: has been removed — ASTableView lets your cell nodes size themselves. This means you no longer have to manually duplicate or factor out layout and sizing logic for dynamically-sized UITableViewCells!
