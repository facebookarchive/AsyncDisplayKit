---
title: ASMultiplexImageNode
layout: docs
permalink: /docs/multiplex-image-node.html
prevPage: editable-text-node.html
---

Let's say your API is out of your control and the images in your app can't be progressive jpegs but you can retrieve a few different sizes of the image asset you want to display. This is where you would use an `ASMultiplexImageNode` instead of an <a href = "/docs/network-image-node.html">ASNetworkImageNode</a>.

In the following example, you're using a multiplex image node in an `ASCellNode` subclass.  After initialization, you typically need to do two things.  First, make sure to set `downloadsIntermediateImages` to `YES` so that the lesser quality images will be downloaded.  

Then, assign an array of keys to the property `imageIdentifiers`.  This list should be in descending order of image quality and will be used by the node to determine what URL to call for each image it will try to load.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
    <pre lang="objc" class="objcCode">
- (instancetype)initWithURLs:(NSDictionary *)urls
{
    ...
     _imageURLs = urls;          // something like @{@"thumb": "/smallImageUrl", @"medium": ...}

    _multiplexImageNode = [[ASMultiplexImageNode alloc] initWithCache:nil 
                                                           downloader:[ASBasicImageDownloader sharedImageDownloader]];
    _multiplexImageNode.downloadsIntermediateImages = YES;
    _multiplexImageNode.imageIdentifiers = @[ @"original", @"medium", @"thumb" ];

    _multiplexImageNode.dataSource = self;
    _multiplexImageNode.delegate   = self;
    ...
}
    </pre>

    <pre lang="swift" class = "swiftCode hidden">

init(urls: [String: NSURL]) {
    imageURLs = urls

    multiplexImageNode = ASMultiplexImageNode(cache: nil, downloader: ASBasicImageDownloader.shared())
    multiplexImageNode.downloadsIntermediateImages = true
    multiplexImageNode.imageIdentifiers = ["original", "medium", "thumb" ]

    multiplexImageNode.dataSource = self
    multiplexImageNode.delegate   = self
    ...
}
    </pre>
</div>
</div>


Then, if you've set up a simple dictionary that holds the keys you provided earlier pointing to URLs of the various versions of your image, you can simply return the URL for the given key in:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
    <pre lang="objc" class="objcCode">
#pragma mark Multiplex Image Node Datasource

- (NSURL *)multiplexImageNode:(ASMultiplexImageNode *)imageNode 
        URLForImageIdentifier:(id)imageIdentifier
{
    return _imageURLs[imageIdentifier];
}
</pre>

    <pre lang="swift" class = "swiftCode hidden">
func multiplexImageNode(_ imageNode: ASMultiplexImageNode, urlForImageIdentifier imageIdentifier: ASImageIdentifier) -> URL? {
    return imageURLs[imageIdentifier]
}
</pre>
</div>
</div>

There are also delegate methods provided to update you on things such as the progress of an image's download, when it has finished displaying etc.  They're all optional so feel free to use them as necessary.  

For example, in the case that you want to react to the fact that a new image arrived, you can use the following delegate callback.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
    <pre lang="objc" class="objcCode">
#pragma mark Multiplex Image Node Delegate

- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode 
            didUpdateImage:(UIImage *)image 
            withIdentifier:(id)imageIdentifier 
                 fromImage:(UIImage *)previousImage 
            withIdentifier:(id)previousImageIdentifier;
{    
        // this is optional, in case you want to react to the fact that a new image came in
}
</pre>

    <pre lang="swift" class = "swiftCode hidden">
func multiplexImageNode(_ imageNode: ASMultiplexImageNode,
                        didUpdate image: UIImage?,
                        withIdentifier imageIdentifier: ASImageIdentifier?,
                        from previousImage: UIImage?,
                        withIdentifier previousImageIdentifier: ASImageIdentifier?) {
    // this is optional, in case you want to react to the fact that a new image came in   
}
</pre>
</div>
</div>

