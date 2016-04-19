---
title: Image Scaling
layout: docs
permalink: /docs/debug-tool-pixel-scaling.html
next: debug-tool-hit-test-slop.html
---

##Visualize ASImageNode.image’s pixel scaling##
This debug feature adds a red text overlay on the bottom right hand corner of an ASImageNode if (and only if) the image’s size in pixels does not match it’s bounds size in pixels, e.g.

```objective-c
imageSizeInPixels = image.size * image.scale
boundsSizeInPixels = bounds.size * contentsScale
scaleFactor = imageSizeInPixels / boundsSizeInPixels

if (scaleFactor != 1.0) {
      NSString *scaleString = [NSString stringWithFormat:@"%.2fx", scaleFactor];
      _debugLabelNode.hidden = NO;
}
```

**This debug feature is useful for quickly determining if you are**
<ul>
  <li><strong>downloading and rendering excessive amounts of image data</li> 
  <li>upscaling a low quality image</strong></li>
</ul>

In the screenshot below of an app with this debug feature enabled, you can see that the avatar image is unnecessarily large (9x too large) for it’s bounds size and that the center picture is more optimized, but not perfectly so. If you control your own endpoint, optimize your API / app to return an optimally sized image.

![screen shot 2016-03-25 at 4 04 59 pm](https://cloud.githubusercontent.com/assets/3419380/14056994/15561daa-f2b1-11e5-9606-59d54d2b5354.png)
##Usage##
In your `AppDelegate.m` file, 
<ul>
  <li>import `AsyncDisplayKit+Debug.h`</li>
  <li>add `[ASImageNode setShouldShowImageScalingOverlay:YES]` at the top of your `didFinishLaunchingWithOptions:` method</li>
</ul>
Make sure to call this method before initializing any ASImageNodes.
