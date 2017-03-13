---
title: Layout Options
layout: docs
permalink: /docs/layout-options.html
prevPage: automatic-layout-debugging.html
nextPage: layer-backing.html
---

When using ASDK, you have three options for layout. Note that UIKit Autolayout is **not** supported by ASDK. 
#Manual Sizing & Layout

This original layout method shipped with ASDK 1.0 and is analogous to UIKit's layout methods. Use this method for ASViewControllers (unless you subclass the node).

`[ASDisplayNode calculateSizeThatFits:]` **vs.** `[UIView sizeThatFits:]`

`[ASDisplayNode layout]` **vs.** `[UIView layoutSubviews]`

###Advantages (over UIKit)
- Eliminates all main thread layout cost
- Results are cached

###Shortcomings (same as UIKit):
- Code duplication between methods
- Logic is not reusable

#Unified Sizing & Layout

This layout method does not have a UIKit analog. It is implemented by calling

`- (ASLayout *)calculateLayoutThatFits: (ASSizeRange)constraint`

###Advantages
- zero duplication
- still async, still cached

###Shortcomings
- logic is not reusable, and is still manual

# Automatic, Extensible Layout

This is the reccomended layout method. It does not have a UIKit analog and is implemented by calling

`- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constraint`
###Advantages
- can reuse even complex, custom layouts
- built-in specs provide automatic layout
- combine to compose new layouts easily
- still async, cached, and zero duplication

The diagram below shows how options #2 and #3 above both result in an ASLayout, except that in option #3, the ASLayout is produced automatically by the ASLayoutSpec.  

<INSERT DIAGRAM>
