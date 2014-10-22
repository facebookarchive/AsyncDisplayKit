![AsyncDisplayKit](https://github.com/facebook/AsyncDisplayKit/blob/master/docs/assets/logo.png)

[![Build Status](https://travis-ci.org/facebook/AsyncDisplayKit.svg)](https://travis-ci.org/facebook/AsyncDisplayKit)
 [![Version](http://img.shields.io/cocoapods/v/AsyncDisplayKit.svg)](http://cocoapods.org/?q=AsyncDisplayKit)
 [![Platform](http://img.shields.io/cocoapods/p/AsyncDisplayKit.svg)]()
 [![License](http://img.shields.io/cocoapods/l/AsyncDisplayKit.svg)](https://github.com/facebook/AsyncDisplayKit/blob/master/LICENSE)

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
`libAsyncDisplayKit.a` to the "Link Binary With Libraries" build phase.
Include `-lc++ -ObjC` in your project linker flags.)

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
  dispatch_sync(dispatch_get_main_queue(), ^{
    [self.view addSubview:node.view];
  });
});
```

You can use `ASImageNode` and `ASTextNode` as drop-in replacements for
UIImageView and UITextView, or [create your own
nodes](https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASDisplayNode%2BSubclasses.h)
to implement node hierarchies or custom drawing.  `ASTableView` is a node-aware
UITableView subclass that can asynchronously preload cell nodes without
blocking the main thread.

### Learn more

* Read the [Getting Started guide](http://asyncdisplaykit.org/guide/)
* Get the [sample projects](https://github.com/facebook/AsyncDisplayKit/tree/master/examples)
* Browse the [API reference](http://asyncdisplaykit.org/appledoc/)
* Watch the [NSLondon talk](http://vimeo.com/103589245)

## Testing

AsyncDisplayKit has extensive unit test coverage.  You'll need to run `pod install` in the root AsyncDisplayKit directory to set up OCMock.

## Contributing

See the CONTRIBUTING file for how to help out.

## License

AsyncDisplayKit is BSD-licensed.  We also provide an additional patent grant.

The files in the /examples directory are licensed under a separate license as specified in each file; documentation is licensed CC-BY-4.0.
