---
title: Hit Test Visualization
layout: docs
permalink: /docs/debug-tool-hit-test-visualization.html
prevPage: corner-rounding.html
nextPage: debug-tool-pixel-scaling.html
---

## Visualize ASControlNode Tappable Areas
<br>
This debug feature adds a semi-transparent highlight overlay on any ASControlNodes containing a `target:action:` pair or gesture recognizer. The tappable range is defined as the ASControlNode’s frame + its `.hitTestSlop` `UIEdgeInsets`. Hit test slop is a unique feature of `ASControlNode` that allows it to extend its tappable range. 

In the screenshot below, you can quickly see that
<ul> 
  <li>The tappable area for the avatar image overlaps the username’s tappable area. In this case, the user avatar image is on top in the view hierarchy and is capturing some touches that should go to the username.</li>
  <li>It would probably make sense to expand the `.hitTestSlop` for the username to allow the user to more easily hit it.</li>
  <li>I’ve accidentally set the hitTestSlop’s UIEdgeInsets to be positive instead of negative for the photo likes count label. It’s going to be hard for a user to tap the smaller target.</li>
</ul>

![screen shot 2016-03-25 at 4 39 23 pm](https://cloud.githubusercontent.com/assets/3419380/14057034/e1e71450-f2b1-11e5-8091-3e6f22862994.png)

## Restrictions
<br>
A _green_ border on the edge(s) of the highlight overlay indicates that that edge of the tapable area is restricted by one of it's superview's tapable areas. An _orange_ border on the edge(s) of the highlight overlay indicates that that edge of the tapable area is clipped by .clipsToBounds of a parent in its hierarchy. 

## Usage
<br>
In your `AppDelegate.m` file, 
<ul>
<li>import <code>AsyncDisplayKit+Debug.h</code></li>
  <li>add <code>[ASControlNode setEnableHitTestDebug:YES]</code> at the top of your AppDelegate's <code>didFinishLaunchingWithOptions:</code> method</li>
</ul>

**Make sure to call this method before initializing any ASControlNodes - including ASButtonNodes, ASImageNodes, and ASTextNodes.**
