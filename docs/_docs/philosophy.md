---
title: Philosophy
layout: docs
permalink: /docs/philosophy.html
prevPage: getting-started.html
nextPage: installation.html
---

#Asynchronous Performance Gains

Texture is a UI framework that was originally born from Facebook’s Paper app. It came as an answer to one of the core questions the Paper team faced. **How can you keep the main thread as clear as possible?**

Nowadays, many apps have a user experience that relies heavily upon continuous gestures and physics based animations. At the very least, your UI is probably dependent on some form of scroll view. These types of user interfaces depend entirely on the main thread and are extremely sensitive to main thread stalls. **A clogged main thread means dropped frames and an unpleasant user experience.**

Texture Nodes are a thread-safe abstraction layer over UIViews and CALayers:

<img src="/static/images/node-view-layer.png" alt="logo">

You can access most view and layer properties when using nodes, the difference is that nodes are rendered concurrently by default, and measured and laid out asynchronously when used <a href = "/docs/layout-engine.html">correctly</a>!

Too see asynchronous performance gains in action, check out the <a href = "https://github.com/texturegroup/texture/tree/master/examples/ASDKgram">`examples/ASDKgram`</a> app which compares a UIKit-implemented social media feed with an Texture-implemented social media feed! 

On an iPhone 6+, the performance may not be radically different, but on a 4S, the difference is dramatic! Which leads us to Texture's next priority...

#A Great App Experience for All Users

Texture's performance gains allow you to easily design a great experience for every app user - across all devices, on all network connections. 

##A Great Developer Experience

Texture also strives to make the developer experience great
- platform compatability: iOS & tvOS
- language compatability: Objective-C & Swift
- requires fewer lines of code to build advanced apps (see <a href = "https://github.com/texturegroup/texture/tree/master/examples/ASDKgram">`examples/ASDKgram`</a> for a direct comparison of a UIKit implemention of an app vs. an equivalent Texture implementation)
- cleaner architecture patterns
- robust code (some really brilliant minds have worked on this for 3+ years).

#Advanced Developer Tools

As Texture has grown, some of the brightest iOS engineers have contributed advanced technologies that will save you, as a developer using Texture, development time. 

###Advanced Technology
- ASRunLoopQueue
- ASRangeController with Intelligent Preloading

###Network Code Savings
- automatic batch fetching (e.g. JSON payloads)
