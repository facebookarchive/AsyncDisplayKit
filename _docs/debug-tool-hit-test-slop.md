---
title: Hit Test Visualization
layout: docs
permalink: /docs/debug-tool-hit-test-slop.html
---
## Visualize tappable areas on ASControlNodes
### Description
This debug feature adds a semi-transparent neon green highlight overlay on any ASControlNodes that have a `target:action:` pair added. The tappable range is defined as the ASControlNode’s frame + its hitTestSlop (UIEdgeInsets used by the ASControlNode to extend it’s tappable range). 

**This debug feature is useful for quickly visualizing an ASControlNode's tappable range.** In the screenshot below, you can quickly see 3 things: (1) The tappable area for the avatar image overlaps the username’s tappable area. In this case, the user avatar image is on top in the view hierarchy and is capturing some touches that should go to the username. (2) It would probably make sense to expand the hitTestSlop for the username to allow the user to more easily hit it. (3) I’ve accidentally set the hitTestSlop’s UIEdgeInsets to be positive instead of negative for the photo likes count label. It’s going to be hard for a user to tap the smaller target.

![screen shot 2016-03-25 at 4 39 23 pm](https://cloud.githubusercontent.com/assets/3419380/14057034/e1e71450-f2b1-11e5-8091-3e6f22862994.png)
### Usage
In your AppDelegate, (1) import `AsyncDisplayKit+Debug.h` and (2) at the top of `didFinishLaunchingWithOptions:` enable this feature by adding` [ASControlNode setEnableHitTestDebug:YES];` Make sure to call this method before initializing any ASControlNodes (including ASButtonNodes, ASImageNodes, and ASTextNodes).
### Limitations
This only works for ASControlNodes’s with `addTarget:action:` pairs added. **It will not work with gesture recognizers.**
