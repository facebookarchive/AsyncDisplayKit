---
layout: docs
title: Making the most of AsyncDisplayKit
permalink: /guide/4/
prev: guide/3/
next: guide/5/
---

## A note on optimisation

AsyncDisplayKit is powerful and flexible, but it is not a panacea.  If your app
has a complex image- or text-heavy user interface, ASDK can definitely help
improve its performance &mdash; but if you're blocking the main thread on
network requests, you should consider rearchitecting a few things first.  :]

So why is it worthwhile to change the way we do view layout and rendering,
given that UIKit has always been locked to the main thread and performant iOS
apps have been shipping since iPhone's launch?

### Modern animations

Until iOS 7, static animations (à la `+[UIView
animateWithDuration:animations:]`) were the standard.  The post-skeuomorphism
redesign brought with it highly-interactive, physics-based animations, with
springs joining the ranks of constant animation functions like
`UIViewAnimationOptionCurveEaseInOut`.

Classic animations aren't actually executed in your app.  They're executed
out-of-process, in the high-priority Core Animation render server.  Thanks to
pre-emptive multitasking, an app can block its main thread continuously without
causing the animation to drop a single frame.

Critically, dynamic animations can't be offloaded the same way, and both
[pop](https://github.com/facebook/pop) and UIKit Dynamics execute physics
simulations on your app's main thread.  This is because executing arbitrary
code in the render server would introduce unacceptable latency, even if it
could be done securely.

Physics-based animations are often interactive, letting you start an animation
and interrupt it before it completes.  Paper lets you fling objects across the
screen and catch them before they land, or grab a view that's being pulled by a
spring and tear it off.  This requires processing touch events and updating
animation targets in realtime &mdash; even short delays for inter-process
communication would shatter the illusion.

(Fun fact:  Inertial scrolling is also a physics animation!  UIScrollView has
always implemented its animations on the main thread, which is why stuttery
scrolling is the hallmark of a slow app.)

### The main-thread bottleneck

Physics animations aren't the only thing that need to happen on the main
thread.  The main thread's [run
loop](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/multithreading/runloopmanagement/runloopmanagement.html)
is responsible for handling touch events and initiating drawing operations
&mdash; and with UIKit in the mix, it also has to render text, decode images,
and do any other custom drawing (e.g., using Core Graphics).

If an iteration of the main thread's run loop takes too long, it will drop an
animation frame and may fail to handle touch events in time.  Each iteration of
the run loop must complete within 16ms in order to drive 60fps animations, and
your own code typically has less than 10ms to execute.  This means that the
best way to keep your app smooth and responsive is to do as little work on the
main thread as possible.

What's more, the main thread only executes on one core!  Single-threaded view
hierarchies can't take advantage of the multicore CPUs in all modern iOS
devices.  This is important for more than just performance reasons &mdash; it's
also critical for battery life.  Running the CPU on all cores for a short time
is preferable to running one core for an extended amount of time:  if the
processor can *race to sleep* by finishing its work and idling faster, it can
spend more time in a low-power mode, improving battery life.

## When to go asynchronous

AsyncDisplayKit really shines when used fully asynchronously, shifting both
measurement and rendering passes off the main thread and onto multiple cores.
This requires a completely node-based hierarchy.  Just as degrading from
UIViews to CALayers disables view-specific functionality like touch handling
from that point on, degrading from nodes to views disables async behaviour.

You don't, however, need to convert your app's entire view hierarchy to nodes.
In fact, you shouldn't!  Asynchronously bringing up your app's core UI, like
navigation elements or tab bars, would be a very confusing experience.  Those
elements of your apps can still be nodes, but should be fully synchronous to
guarantee a fully-usable interface as quickly as possible.  (This is why
UIWindow has no node equivalent.)

There are two key situations where asynchronous hierarchies excel:

1.  *Parallelisation*.  Measuring and rendering UITableViewCells (or your app's
    equivalent, e.g., story cards in Paper) are embarrassingly parallel
    problems.  Table cells typically have a fixed width and variable height
    determined by their contents &mdash; the argument to `-measure:` for one
    cell doesn't depend on any other cells' calculations, so we can enqueue an
    arbitrary number of cell measurement passes at once.

2.  *Preloading*.  An app with five tabs should synchronously load the first
    one so content is ready to go as quickly as possible.  Once this is
    complete and the CPU is idle, why not asynchronously prepare the other tabs
    so the user doesn't have to wait?  This is inconvenient with views, but
    very easy with nodes.

Paper's asynchronous rendering starts at the story strip.  You should profile
your app and watch how people use it in the wild to decide what combination of
synchrony and asynchrony yields the best user experience.

## Additional optimisations

Complex hierarchies &mdash; even when rendered asynchronously &mdash; can
impose a cost because of the sheer number of views involved.  Working around
this can be painful, but AsyncDisplayKit makes it easy!

*   *Layer-backing*.  In some cases, you can substantially improve your app's
    performance by using layers instead of views.  Manually converting
    view-based code to layers is laborious due to the difference in APIs.
    Worse, if at some point you need to enable touch handling or other
    view-specific functionality, you have to manually convert everything back
    (and risk regressions!).

    With nodes, converting an entire subtree from views to layers is as simple
    as...

        rootNode.layerBacked = YES;

    ...and if you need to go back, it's as simple as deleting one line.  We
    recommend enabling layer-backing as a matter of course in any custom node
    that doesn't need touch handling.
    
*   *Precompositing*.  Flattening an entire view hierarchy into a single layer
    also improves performance, but comes with a hit to maintainability and
    hierarchy-based reasoning.  Nodes can do this for you too!

        rootNode.shouldRasterizeDescendants = YES;

    ...will cause the entire node hierarchy from that point on to be rendered
    into one layer.

Next up:  AsyncDisplayKit, under the hood.
