---
title: Image Scaling
layout: docs
permalink: /docs/debug-tool-pixel-scaling.html
prevPage: debug-tool-hit-test-visualization.html
nextPage: debug-tool-ASRangeController.html
---

##Visualize ASImageNode.image’s pixel scaling##
<br>
This debug feature adds a red text overlay on the bottom right hand corner of an ASImageNode if (and only if) the image’s size in pixels does not match it’s bounds size in pixels, e.g.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
CGFloat imageSizeInPixels = image.size.width * image.size.height;
CGFloat boundsSizeInPixels = imageView.bounds.size.width * imageView.bounds.size.height;
CGFloat scaleFactor = imageSizeInPixels / boundsSizeInPixels;

if (scaleFactor != 1.0) {
      NSString *scaleString = [NSString stringWithFormat:@"%.2fx", scaleFactor];
      _debugLabelNode.hidden = NO;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
let imageSizeInPixels = image.size.width * image.size.height
let boundsSizeInPixels = imageView.bounds.size.width * imageView.bounds.size.height
let scaleFactor = imageSizeInPixels / boundsSizeInPixels

if scaleFactor != 1.0 {
      let scaleString = "\(scaleFactor)"
      _debugLabelNode.hidden = false
}
</pre>
</div>
</div>


<b>This debug feature is useful for quickly determining if you are</b>

<ul>
  <li><strong>downloading and rendering excessive amounts of image data</li> 
  <li>upscaling a low quality image</strong></li>
</ul>

In the screenshot below of an app with this debug feature enabled, you can see that the avatar image is unnecessarily large (9x too large) for it’s bounds size and that the center picture is more optimized, but not perfectly so. If you control your own endpoint, make sure to return an optimally sized image.

![screen shot 2016-03-25 at 4 04 59 pm](https://cloud.githubusercontent.com/assets/3419380/14056994/15561daa-f2b1-11e5-9606-59d54d2b5354.png)

## Usage ##
<br>
In your `AppDelegate.m` file, 
<ul>
  <li>import `AsyncDisplayKit+Debug.h`</li>
  <li>add `[ASImageNode setShouldShowImageScalingOverlay:YES]` at the top of your AppDelegate's `didFinishLaunchingWithOptions:` method</li>
</ul>

**Make sure to call this method before initializing any ASImageNodes.**
