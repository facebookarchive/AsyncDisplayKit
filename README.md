![AsyncDisplayKit](https://github.com/facebook/AsyncDisplayKit/blob/master/docs/assets/logo.png)

[![Apps Using](https://img.shields.io/badge/Apps%20Using%20ASDK-%3E4,646-28B9FE.svg)](http://cocoapods.org/pods/AsyncDisplayKit)
[![Downloads](https://img.shields.io/badge/Total%20Downloads-%3E475,500-28B9FE.svg)](http://cocoapods.org/pods/AsyncDisplayKit)

[![Platform](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS-orange.svg)](http://AsyncDisplayKit.org)
[![Languages](https://img.shields.io/badge/languages-ObjC%20%7C%20Swift-orange.svg)](http://AsyncDisplayKit.org)

[![Version](https://img.shields.io/cocoapods/v/AsyncDisplayKit.svg)](http://cocoapods.org/pods/AsyncDisplayKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-59C939.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/facebook/AsyncDisplayKit.svg)](https://travis-ci.org/facebook/AsyncDisplayKit)
[![License](https://img.shields.io/cocoapods/l/AsyncDisplayKit.svg)](https://github.com/facebook/AsyncDisplayKit/blob/master/LICENSE)
 

AsyncDisplayKit is an iOS framework that keeps even the most complex user
interfaces smooth and responsive.  It was originally built to make Facebook's
[Paper](https://facebook.com/paper) possible, and goes hand-in-hand with
[pop](https://github.com/facebook/pop)'s physics-based animations &mdash; but
it's just as powerful with UIKit Dynamics and conventional app designs.

### Quick start  

ASDK is available on [CocoaPods](http://cocoapods.org).  Add the following to your Podfile:

```ruby
pod 'AsyncDisplayKit'
```
 
(ASDK can also be used as a regular static library:  Copy the project to your
codebase manually, adding `AsyncDisplayKit.xcodeproj` to your workspace.  Add
`libAsyncDisplayKit.a`, MapKit, AssetsLibrary, and Photos to the "Link Binary With
Libraries" build phase.  Include `-lc++ -ObjC` in your project linker flags.)

Import the framework header, or create an [Objective-C bridging
header](https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html)
if you're using Swift:

```objective-c
#import <AsyncDisplayKit/AsyncDisplayKit.h>
```

AsyncDisplayKit Nodes are a thread-safe abstraction layer over UIViews and
CALayers:

![node-view-layer diagram](https://github.com/facebook/AsyncDisplayKit/blob/master/docs/assets/node-view-layer.png)

You can construct entire node hierarchies in parallel, or instantiate and size
a single node on a background thread &mdash; for example, you could do
something like this in a UIViewController: 

```objective-c
dispatch_async(_backgroundQueue, ^{
  ASTextNode *node = [[ASTextNode alloc] init];
  node.attributedString = [[NSAttributedString alloc] initWithString:@"hello!"
                                                          attributes:nil];
  [node measure:CGSizeMake(screenWidth, FLT_MAX)];
  node.frame = (CGRect){ CGPointZero, node.calculatedSize };

  // self.view isn't a node, so we can only use it on the main thread
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.view addSubview:node.view];
  });
});
```

In Swift:

```swift
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) {
  let node = ASTextNode()
  node.attributedString = NSAttributedString(string: "hello")
  node.measure(CGSize(width: screenWidth, height: CGFloat.max))
  node.frame = CGRect(origin: CGPointZero, size: node.calculatedSize)
            
  // self.view isn't a node, so we can only use it on the main thread
  dispatch_async(dispatch_get_main_queue()) {
   self.view.addSubview(node.view)
  }
}
```

AsyncDisplayKit at a glance:

* `ASImageNode` and `ASTextNode` are drop-in replacements for UIImageView and
  UITextView.
* `ASMultiplexImageNode` can load and display progressively higher-quality
  variants of an image over a slow cell network, letting you quickly show a
  low-resolution photo while the full size downloads.
* `ASNetworkImageNode` is a simpler, single-image counterpart to the Multiplex
  node.
* `ASTableView` and `ASCollectionView` are a node-aware UITableView and
  UICollectionView, respectively, that can asynchronously preload cell nodes
  &mdash; from loading network data to rendering &mdash; all without blocking
  the main thread.

You can also easily [create your own
nodes](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASDisplayNode%2BSubclasses.h)
to implement node hierarchies or custom drawing.

## Learn more

* Read the [Getting Started guide](http://asyncdisplaykit.org/docs/getting-started.html)
* Get the [sample projects](https://github.com/facebook/AsyncDisplayKit/tree/master/examples)
* Browse the [API reference](http://asyncdisplaykit.org/appledocs.html)
* Watch the [NSLondon talk](http://vimeo.com/103589245) or the [NSSpain talk](https://www.youtube.com/watch?v=RY_X7l1g79Q)

## Getting Help

We use Slack for real-time debugging, community updates, and general talk about ASDK. Signup at http://asdk-slack-auto-invite.herokuapp.com or email AsyncDisplayKit(at)gmail.com to get an invite.

## Testing

AsyncDisplayKit has extensive unit test coverage.  You'll need to run `pod install` in the root AsyncDisplayKit directory to set up OCMock.

## Contributing

See the CONTRIBUTING file for how to help out.

## License

AsyncDisplayKit is BSD-licensed.  We also provide an additional patent grant.

The files in the /examples directory are licensed under a separate license as specified in each file; documentation is licensed CC-BY-4.0.
