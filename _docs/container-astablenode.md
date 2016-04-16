---
title: ASTableNode
layout: docs
permalink: /docs/container-astablenode.html
next: container-ascollectionnode.html
---

ASTableNode is equivalent to UIKit's UITableView.  

<div class = "note">
If you've used previous versions of ASDK, you'll notice that ASTableView has been removed in favor of ASTableNode.   ASTableView (an actual UITableView subclass) is still in use as an internal property of ASTableNode but should no longer be used by itself.  

That being said, you can still grab a reference to the underlying ASTableView if necessary by accessing the .view property of an ASTableNode.
</div>

ASTableNode can be used in place of any UITableView.  The only requirements are that you replace your 

<code>-cellForRowAtIndexPath:</code> 

method with a 

<code>-nodeForRowAtIndexPath:</code> 

or

<code>-nodeBlockForRowAtIndexPath:</code>

Otherwise, a table node has mostly the same delegate and dataSource methods that a table view would.

An important thing to notice is that ASTableNode does not provide a method called:

<code>-tableNode:HeightForRowAtIndexPath:</code>

This is because in ASDK, nodes are responsible for determining their height themselves which means you no longer have to write code to determine this detail at the view controller level.

