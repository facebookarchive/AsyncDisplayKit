---
title: Subclassing 
layout: docs
permalink: /docs/subclassing.html
prevPage: containers-overview.html
nextPage: faq.html
---
The most important distinction when creating a subclass is whether you writing an ASViewController or an ASDisplayNode. This sounds obvious, but because some of these differences are subtle, it is important to keep this top of mind. 

## ASDisplayNode
<br>
While subclassing nodes is similar to writing a UIView subclass, there are a few guidelines to follow to ensure that both that you're utilizing the framework to its full potential and that your nodes behave as expected.

### `-init`

This method is called on a **background thread** when using nodeBlocks. However, because no other method can run until -init is finished, it should never be necessary to have a lock in this method. 

The most important thing to remember is that your init method must be capable of being called on any queue. Most notably, this means you should never initialize any UIKit objects, touch the view or layer of a node (e.g. `node.layer.X` or `node.view.X`) or add any gesture recognizers in your initializer. Instead, do these things in `-didLoad`. 

### `-didLoad`

This method is conceptually similar to UIViewController's `-viewDidLoad` method and is the point where the backing view has been loaded.  It is guaranteed to be called on the **main thread** and is the appropriate place to do any UIKit things (such as adding gesture recognizers, touching the view / layer, initializing UIKIt objects). 

### `-layoutSpecThatFits:`

This method defines the layout and does the heavy calculation on a **background thread**. This method is where you build out a layout spec object that will produce the size of the node, as well as the size and position of all subnodes.  This is where you will put the majority of your layout code. 

The layout spec object that you create is malleable up until the point that it is return in this method.  After this point, it will be immutable.  It's important to remember not to cache layout specs for use later but instead to recreate them when necessary.

Because it is run on a background thread, you should not set any `node.view` or `node.layer` properties here. Also, unless you know what you are doing, do not create any nodes in this method. Additionally, it is not neccessary to begin this method with a call to super, unlike other method overrides. 

### `-layout`  

The call to super in this method is where the results of the layoutSpec are applied; Right after the call to super in this method, the layout spec will have been calculated and all subnodes will have been measured and positioned. 

`-layout` is conceptually similar to UIViewController's `-viewWillLayoutSubviews`. This is a good spot to change the hidden property, set view based properties if needed (not layoutable properties) or set background colors. You could put background color setting in -layoutSpecThatFits:, but there may be timing problems. If you happen to be using any UIViews, you can set their frames here. However, you can always create a node wrapper with `-initWithViewBlock:` and then size this on the background thread elsewhere. 

This method is called on the **main thread**. However, if you are using layout Specs, you shouldn't rely on this method too much, as it is much preferable to do layout off the main thread. Less than 1 in 10 subclasses will need this.

One great use of `-layout` is for the specific case in which you want a subnode to be your exact size. E.g. when you want a collectionNode to take up the full screen. This case is not supported well by layout specs and it is often easiest to set the frame manually with a single line in this method:

```
subnode.frame = self.bounds;
```

If you desire the same effect in a ASViewController, you can do the same thing in -viewWillLayoutSubviews, unless your node is the node in initWithNode: and in that case it will do this automatically.

## ASViewController
<br>
An `ASViewController` is a regular `UIViewController` subclass that has special features to manage nodes. Since it is a UIViewController subclass, all methods are called on the **main thread** (and you should always create an ASViewController on the main thread). 

###`-init` 

This method is called once, at the very begining of an ASViewController's lifecycle. As with UIViewController initialization, it is best practice to **never access** `self.view` or `self.node.view` in this method as it will force the view to be created early. Instead, do any view access in -viewDidLoad. 

ASViewController's designated initializer is `initWithNode:`. A typical initializer will look something like the code below. Note how the ASViewController's node is created _before_ calling super. An ASViewController manages a node similarly to how a UIViewController manages a view, but the initialization is slightly different. 

``` 
- (instancetype)init
{
  _pagerNode = [[ASPagerNode alloc] init];
  self = [super initWithNode:_pagerNode];
  
  // setup any instance variables or properties here
  if (self) {
    _pagerNode.dataSource = self;
    _pagerNode.delegate = self;
  }
  
  return self;
}
```
       
###`-loadView`

We recommend that you do not use this method because it is has no particular advantages over `-viewDidLoad` and has some disadvantages. However, it is safe to use as long as you do not set the `self.view` property to a different value. The call to [super loadView] will set it to the `node.view` for you.

###`-viewDidLoad`  

This method is called once in a ASViewController's lifecycle, immediately after `-loadView`. This is the earliest time at which you should access the node's view. It is a great spot to put any **setup code that should only be run once and requires access to the view/layer**, such as adding a gesture recognizer. 

Layout code should never be put in this method, because it will not be called again when geometry changes. Note this is equally true for UIViewController; it is bad practice to put layout code in this method even if you don't currently expect geometry changes. 

###`-viewWillLayoutSubviews`  

This method is called at the exact same time as a node's `-layout` method and it may be called multiple times in a ASViewController's lifecycle; it will be called whenever the bounds of the ASViewController's node are changed (including rotation, split screen, keyboard presentation) as well as when there are changes to the hierarchy (children being added, removed, or changed in size). 

For consistency, it is best practice to put all layout code in this method. Because it is not called very frequently, even code that does not directly depend on the size belongs here.  

###`-viewWillAppear:` / `-viewDidDisappear:`

These methods are called just before the ASViewController's node appears on screen and just after it is onscreen. These methods provide a good opportunity to start or stop animations related to the presentation or dismissal of your controller. This is also a good place to make a log of a user action. 

Although these methods may be called multiple times and geometry information is available, they are not called for all geometry changes and so should not be used for core layout code (beyond setup required for specific animations). 

