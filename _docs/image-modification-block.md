---
title: Image Modification Blocks
layout: docs
permalink: /docs/image-modification-block.html
prevPage: implicit-hierarchy-mgmt.html
nextPage: placeholder-fade-duration.html
---

Many times, operations that would affect the appearance of an image you're displaying are big sources of main thread work.  Naturally, you want to move these to a background thread.  

By assigning an `imageModificationBlock` to your imageNode, you can define a set of transformations that need to happen asynchronously to any image that gets set on the imageNode.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
_backgroundImageNode.imageModificationBlock = ^(UIImage *image) {
	UIImage *newImage = [image applyBlurWithRadius:30 
										 tintColor:[UIColor colorWithWhite:0.5 alpha:0.3] 
							 saturationDeltaFactor:1.8 
							 			 maskImage:nil];
	return newImage ? newImage : image;
};

//some time later...

_backgroundImageNode.image = someImage;
</pre>

<pre lang="swift" class = "swiftCode hidden">
backgroundImageNode.imageModificationBlock = { image in
    let newImage = image.applyBlurWithRadius(30, tintColor: UIColor(white: 0.5, alpha: 0.3), 
    								 saturationDeltaFactor: 1.8, 
    								 			 maskImage: nil)
    return (newImage != nil) ? newImage : image
}

//some time later...

backgroundImageNode.image = someImage
</pre>
</div>
</div>

The image named "someImage" will now be blurred asynchronously before being assigned to the imageNode to be displayed.

