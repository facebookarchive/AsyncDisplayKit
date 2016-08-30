---
title: Layout Basics
layout: docs
permalink: /docs/automatic-layout-basics.html
prevPage: scroll-node.html
nextPage: automatic-layout-containers.html
---

##Box Model Layout

ASLayout is an automatic, asynchronous, purely Objective-C box model layout feature. It is a simplified version of CSS flex box, loosely inspired by ComponentKit’s Layout. It is designed to make your layouts extensible and reusable.

`UIView` instances store position and size in their `center` and `bounds` properties. As constraints change, Core Animation performs a layout pass to call `layoutSubviews`, asking views to update these properties on their subviews. 

`<ASLayoutable>` instances (all ASDisplayNodes and subclasses) do not have any size or position information. Instead, AsyncDisplayKit calls the `layoutSpecThatFits:` method with a given size constraint and the component must return a structure describing both its size, and the position and sizes of its children.

##Terminology

The terminology is a bit confusing, so here is a brief description of all of the ASDK automatic layout players:

Items that conform to the **\<ASLayoutable\> protocol** declares a method for measuring the layout of an object.  A layout is defined by an ASLayout return value, and must specify 1) the size (but not position) of the layoutable object, and 2) the size and position of all of its immediate child objects. The tree recursion is driven by parents requesting layouts from their children in order to determine their size, followed by the parents setting the position of the children once the size is known.
 
This protocol also implements a "family" of layoutable protocols - the `AS{*}LayoutSpec` protocols. These protocols contain layout options that can be used for specific layout specs. For example, `ASStackLayoutSpec` has options defining how a layoutable should shrink or grow based upon available space. These layout options are all stored in an `ASLayoutOptions` class (that is defined in `ASLayoutablePrivate`). Generally you needn't worry about the layout options class, as the layoutable protocols allow all direct access to the options via convenience properties. If you are creating custom layout spec, then you can extend the backing layout options class to accommodate any new layout options.

All ASDisplayNodes and subclasses as well as the `ASLayoutSpecs` conform to this protocol. 

An **`ASLayoutSpec`** is an immutable object that describes a layout. Creation of a layout spec should only happen by a user in layoutSpecThatFits:. During that method, a layout spec can be created and mutated. Once it is passed back to ASDK, the isMutable flag will be set to NO and any further mutations will cause an assert.

Every ASLayoutSpec must act on at least one child. The ASLayoutSpec has the responsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec, only require a single child. Others, have multiple. 

You don’t need to be aware of **`ASLayout`** except to know that it represents a computed immutable layout tree and is returned by objects conforming to the `<ASLayoutable>` protocol.

##Layout for UIKit Components:
- for UIViews that are added directly, you will still need to manually lay it out in `didLoad:`
- for UIViews that are added via `[ASDisplayNode initWithViewBlock:]` or its variants, you can then include it in `layoutSpecThatFits:`

