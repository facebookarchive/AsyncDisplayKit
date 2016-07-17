---
title: ASRunLoopQueue
layout: docs
permalink: /docs/asrunloopqueue.html
prevPage: asenvironment.html
---

Even with main thread work, AsyncDisplayKit is able to dramatically reduce its impact on the user experience by way of the rather amazing ASRunLoopQueue. 

`ASRunloopQueue` breaks up operations that must be performed on the main thread into far smaller chunks, easily 1/10th of the size that they otherwise would be, so that operation such as allocating UIViews or even destroying objects can be spread out and allow the run loops to more frequently turn. This more periodic turning allows the device to much more frequently check if a user touch has started or if an animation timer requires a new frame to be drawn, allowing far greater responsiveness even when the device is very busy and processing a large queue of main thread work.

It's a longer discussion why this kind of technique is extremely challenging to implement with `UIKit`, but it has to do with the fact that `AsyncDisplayKit` prepares content in advance, giving it a buffer of time where it can spread out the creation of these objects in tiny chunks. If it doesn't finish by the time it needs to be on screen, then it finishes the rest of what needs to be created in a single chunk. `UIKit` has no similar mechanisms to create things in advance, and there is always just one huge chunk as a view controller or cell needs to come on screen.

**ASRunLoopQueue is enabled by default when running AsyncDisplayKit.** A developer does not need to be aware of it's existence except to know that it helps reduce main thread blockage. 
