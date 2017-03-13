---
title: ASVideoNode
layout: docs
permalink: /docs/video-node.html
prevPage: network-image-node.html
nextPage: map-node.html
---

`ASVideoNode` provides a convenient and performant way to display videos in your app.  

<div class = "note"><strong>Note:</strong> If you use `ASVideoNode` in your application, you must link `AVFoundation` since it uses `AVPlayerLayer` and other `AVFoundation` classes under the hood.</div>

### Basic Usage

The easiest way to use `ASVideoNode` is to assign it an `AVAsset`.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
ASVideoNode *videoNode = [[ASVideoNode alloc] init];

AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"http://www.w3schools.com/html/mov_bbb.mp4"]];
videoNode.asset = asset;
</pre>

<pre lang="swift" class = "swiftCode hidden">
let videoNode = ASVideoNode()

let asset = AVAsset(URL: NSURL(string: "http://www.w3schools.com/html/mov_bbb.mp4"))
videoNode.asset = asset
</pre>
</div>
</div>

### Autoplay, Autorepeat, and Muting

You can configure the way your video node reacts to various events with a few simple `BOOL`s.

If you'd like your video to automaticaly play when it enters the visible range, set the `shouldAutoplay` property to `YES`.  Setting `shouldAutoRepeat` to `YES` will cause the video to loop indefinitely, and, of course, setting `muted` to `YES` will turn the video's sound off.

To set up a node that automatically plays once silently, you would just do the following.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
videoNode.shouldAutoplay = YES;
videoNode.shouldAutorepeat = NO;
videoNode.muted = YES;
</pre>
<pre lang="swift" class = "swiftCode hidden">
videoNode.shouldAutoplay = true
videoNode.shouldAutorepeat = false
videoNode.muted = true
</pre>
</div>
</div>

### Placeholder Image

Since video nodes inherit from `ASNetworkImageNode`, you can use the `URL` property to assign a placeholder image.  If you decide not to, the first frame of your video will automatically decoded and used as the placeholder instead.

<img width = "300" src = "/static/images/video.gif"/>


### ASVideoNode Delegate

There are a ton of delegate methods available to you that allow you to react to what's happening with your video.  For example, if you want to react to the player's state changing, you can use:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState;
</pre>
<pre lang="swift" class = "swiftCode hidden">
videoNode(videoNode:willChangePlayerState:toState:)
</pre>
</div>
</div>

The easiest way to see them all is to take a look at the `ASVideoNode` header file.

