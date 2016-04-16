---
title: ASCollectionNode
layout: docs
permalink: /docs/container-ascollectionnode.html
next: containers-aspagernode.html
---

ASCollectionNode can be used in place of any UICollectionView.  The only requirements are that you replace your 

<code>-cellForRowAtIndexPath:</code> 

method with a 

<code>-nodeForRowAtIndexPath:</code> 

or

<code>-nodeBlockForRowAtIndexPath:</code>

Otherwise, a collection node has mostly the same delegate and dataSource methods that a collection view would and is compatible with most UICollectionViewLayouts.

