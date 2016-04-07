---
title: Debug Tools
layout: docs
permalink: /docs/debugging.html
---

## Visualize ASImageNode.image’s pixel scaling
### Description
This debug feature adds a red text label overlay on the bottom right hand corner of an ASImageNode if (and only if) the image’s size in pixels does not match it’s bounds size in pixels, e.g.

`imageSizeInPixels = image.size * image.scale`
`boundsSizeInPixels = bounds.size * contentsScale`
`scaleFactor = imageSizeInPixels / boundsSizeInPixels`

`if (scaleFactor != 1.0) {`
      `NSString *scaleString = [NSString stringWithFormat:@"%.2fx", scaleFactor];`
      `_debugLabelNode.hidden = NO;`
`}`

This debug feature is useful for **quickly determining if you are (1) downloading and rendering excessive amounts of image data or (2) upscaling a low quality image**. In the screenshot below, you can quickly see that the avatar image is unnecessarily large for it’s bounds size and that the center picture is more optimized, but not perfectly so. If you are using an external data source (such as the 500px API used in the example), it's likely that you won’t be able to get the scaleFactor to exactly 1.0. However, if you control your own endpoint, optimize your API / app to return a correctly sized image!

![screen shot 2016-03-25 at 4 04 59 pm](https://cloud.githubusercontent.com/assets/3419380/14056994/15561daa-f2b1-11e5-9606-59d54d2b5354.png)
### Usage
In your AppDelegate, (1) import `AsyncDisplayKit+Debug.h` and (2) at the top of `didFinishLaunchingWithOptions:` enable this feature by adding `[ASImageNode setShouldShowImageScalingOverlay:YES];` Make sure to call this method before initializing any ASImageNodes.
## Visualize tappable areas on ASControlNodes
### Description
This debug feature adds a semi-transparent neon green highlight overlay on any ASControlNodes that have a `target:action:` pair added. The tappable range is defined as the ASControlNode’s frame + its hitTestSlop (UIEdgeInsets used by the ASControlNode to extend it’s tappable range). 

**This debug feature is useful for quickly visualizing an ASControlNode's tappable range.** In the screenshot below, you can quickly see 3 things: (1) The tappable area for the avatar image overlaps the username’s tappable area. In this case, the user avatar image is on top in the view hierarchy and is capturing some touches that should go to the username. (2) It would probably make sense to expand the hitTestSlop for the username to allow the user to more easily hit it. (3) I’ve accidentally set the hitTestSlop’s UIEdgeInsets to be positive instead of negative for the photo likes count label. It’s going to be hard for a user to tap the smaller target.

![screen shot 2016-03-25 at 4 39 23 pm](https://cloud.githubusercontent.com/assets/3419380/14057034/e1e71450-f2b1-11e5-8091-3e6f22862994.png)
### Usage
In your AppDelegate, (1) import `AsyncDisplayKit+Debug.h` and (2) at the top of `didFinishLaunchingWithOptions:` enable this feature by adding` [ASControlNode setEnableHitTestDebug:YES];` Make sure to call this method before initializing any ASControlNodes (including ASButtonNodes, ASImageNodes, and ASTextNodes).
### Limitations
This only works for ASControlNodes’s with `addTarget:action:` pairs added. **It will not work with gesture recognizers.**
## Visualize ASRangeController tuning parameters - PR #1390
### Description 
This debug feature adds a semi-transparent subview in the bottom right hand corner of the sharedApplication keyWindow that visualizes the ASRangeTuningParameters per each ASLayoutRangeType for each visible (on-screen) instance of ASRangeController. 

- The instances of ASRangeController are represented as bars
- As you scroll around within ASTable/CollectionViews you can see the parameters (green = Visible, yellow = Display, and red = FetchData) move relative to each other. 
- White arrows on the L and R sides of the individual RangeController bar views indicate the scrolling direction so that you can determine the leading / trailing tuning parameters (especially useful for vertically-oriented rangeControllers whose leading edge might be unclear within the horizontally-oriented bar view). 
- The white debug label above the RangeController bar displays the RangeController dataSource’s class name to differentiate between nested views.
- The overlay can be moved with a panning gesture in order to see content under it.

This debug feature is useful for highly optimized ASDK apps that require tuning of any ASRangeController. Or for anyone who is curious about how ASRangeControllers work. 

The examples/VerticalWithinHorizontal app picture below contains an ASPagerNode with embedded ASTableViews. In the screenshot with this feature enabled, you can see the two range controllers - ASTableView and ASCollectionView (ASPagerNode) - in the overlay. 
- The white arrows to the right of the rangeController bars indicate that the user is currently scrolling down through the table and right through the ASCollectionView/PagerNode. 
- The ASTableView rangeController bar indicates that the range parameters are tuned to both fetch and decode more data in the downward table direction rather than in the reverse direction (which makes sense as the user is scrolling down). 
- Since it’s less obvious whether or not the user will page to the right or left next, the ASCollectionView is tuned to fetch and decode equal amounts of data in each direction. 
- In the video, you can see as the user scrolls between pages, that new ASTableView rangeControllers are created and removed in the overlay view. 
![bc0b98f0-ebb8-11e5-8f50-421cb0f320c2](https://cloud.githubusercontent.com/assets/3419380/14057072/ef7f63a0-f2b2-11e5-92a5-f65b2d207e63.png)

### Video Demo
https://drive.google.com/file/d/0B1BArZ05bNhzVy1jSW9FeEVXUjg/view

### Usage
In your AppDelegate, (1) import `AsyncDisplayKit+Debug.h` and (2) at the top of `didFinishLaunchingWithOptions:` enable this feature by adding `[ASRangeController setShouldShowRangeDebugOverlay:YES];` Make sure to call this method before initializing any component that uses an ASRangeControllers (ASTableView, ASCollectionView).
### Limitations
- code performance is iffy
- only shows onscreen ASRangeControllers
- currently the ratio of red (fetch data), yellow (display) and green (visible) are relative to each other, but not between each bar view. So you cannot compare individual bars to eachother
- configure the debug label to display more useful information - perhaps the actual values of the tuning parameters?
- rather than displaying the ideal tuning parameters, show the achieved ones
- rather than showing the tuning parameters in a bar representation, show the actual nodes in each state

## ASLayoutSpecPlayground...coming soon!
