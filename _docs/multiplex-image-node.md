---
title: ASMultiplexImageNode
layout: docs
permalink: /docs/multiplex-image-node.html
next: map-node.html
---

Let's say your API is out of your control and the images in your app can't be progressive jpegs but you can retrieve a few different sizes of the image asset you want to display. This is where you would use an ASMultiplexImageNode instead of an <a href = "/docs/network-image-node.html">ASNetworkImageNode</a>.

In the following example, you're using a multiplex image node in an ASCellNode subclass.  After initialization, you typically need to do two things.  First, make sure to set <code>downloadsIntermediateImages</code> to <code>YES</code> so that the lesser quality images will be downloaded.  

Then, assign an array of keys to the property <code>imageIdentifiers</code>.  This list should be in descending order of image quality and will be used by the node to determine what URL to call for each image it will try to load.

```
- (instancetype)initWithURLs:(NSDictionary *)urls
{
     _imageUrls = urls;          // something like @{@"thumb": "/smallImageUrl", @"medium": ...}

    _multiplexImageNode = [[ASMultiplexImageNode alloc] initWithCache:nil 
    													   downloader:[ASBasicImageDownloader sharedImageDownloader]];
    _multiplexImageNode.downloadsIntermediateImages = YES;
    _multiplexImageNode.imageIdentifiers = @[ @"original", @"medium", @"thumb" ];

    _multiplexImageNode.dataSource = self;
    _multiplexImageNode.delegate = self;
	…
}
```

Then, if you've set up a simple dictionary that holds the keys you provided earlier pointing to URLs of the various versions of your image, you can simply return the URL for the given key in:

```
#pragma mark Multiplex Image Node Datasource

- (NSURL *)multiplexImageNode:(ASMultiplexImageNode *)imageNode 
        URLForImageIdentifier:(id)imageIdentifier
{
    return _imageUrls[imageIdentifier];
}
```

Then, in the case that you want to react to the fact that a new image arrived, you can use the following delegate callback.

```
#pragma mark Multiplex Image Node Delegate

- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode 
            didUpdateImage:(UIImage *)image 
            withIdentifier:(id)imageIdentifier 
                 fromImage:(UIImage *)previousImage 
            withIdentifier:(id)previousImageIdentifier;
{    
		// this is optional, in case you want to react to the fact that a new image came in
}
```