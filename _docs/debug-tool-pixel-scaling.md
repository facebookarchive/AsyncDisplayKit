---
title: Image Scaling
layout: docs
permalink: /docs/debug-tool-pixel-scaling.html
next: debug-tool-hit-test-slop.html
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
