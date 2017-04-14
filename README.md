<h1>AsyncDisplayKit has been moved and renamed: <a href="https://github.com/texturegroup/texture/">Texture</a></h1>
<a href="https://medium.com/@Pinterest_Engineering/introducing-texture-a-new-home-for-asyncdisplaykit-e7c003308f50"><img src="https://github.com/TextureGroup/Texture/raw/master/docs/static/images/logo.png" alt="Texture Logo" /></a>
<h2 style="border-bottom:none !important"><a href="https://medium.com/@Pinterest_Engineering/introducing-texture-a-new-home-for-asyncdisplaykit-e7c003308f50">Learn more here</a></h2>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>

![AsyncDisplayKit](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/logo.png)

[![Apps Using](https://img.shields.io/cocoapods/at/AsyncDisplayKit.svg?label=Apps%20Using%20ASDK&colorB=28B9FE)](http://cocoapods.org/pods/AsyncDisplayKit)
[![Downloads](https://img.shields.io/cocoapods/dt/AsyncDisplayKit.svg?label=Total%20Downloads&colorB=28B9FE)](http://cocoapods.org/pods/AsyncDisplayKit)

[![Platform](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS-orange.svg)](http://AsyncDisplayKit.org)
[![Languages](https://img.shields.io/badge/languages-ObjC%20%7C%20Swift-orange.svg)](http://AsyncDisplayKit.org)

[![Version](https://img.shields.io/cocoapods/v/AsyncDisplayKit.svg)](http://cocoapods.org/pods/AsyncDisplayKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-59C939.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/AsyncDisplayKit.svg)](https://github.com/facebook/AsyncDisplayKit/blob/master/LICENSE)

## Installation

ASDK is available via CocoaPods or Carthage. See our [Installation](http://asyncdisplaykit.org/docs/installation.html) guide for instructions.

## Performance Gains

AsyncDisplayKit's basic unit is the `node`. An ASDisplayNode is an abstraction over `UIView`, which in turn is an abstraction over `CALayer`. Unlike views, which can only be used on the main thread, nodes are thread-safe: you can instantiate and configure entire hierarchies of them in parallel on background threads.

To keep its user interface smooth and responsive, your app should render at 60 frames per second — the gold standard on iOS. This means the main thread has one-sixtieth of a second to push each frame. That's 16 milliseconds to execute all layout and drawing code! And because of system overhead, your code usually has less than ten milliseconds to run before it causes a frame drop.

AsyncDisplayKit lets you move image decoding, text sizing and rendering, layout, and other expensive UI operations off the main thread, to keep the main thread available to respond to user interaction.

## Advanced Developer Features

As the framework has grown, many features have been added that can save developers tons of time by eliminating common boilerplate style structures common in modern iOS apps. If you've ever dealt with cell reuse bugs, tried to performantly preload data for a page or scroll style interface or even just tried to keep your app from dropping too many frames you can benefit from integrating ASDK.

## Learn More

* Read the our [Getting Started](http://asyncdisplaykit.org/docs/getting-started.html) guide
* Get the [sample projects](https://github.com/facebook/AsyncDisplayKit/tree/master/examples)
* Browse the [API reference](http://asyncdisplaykit.org/appledocs.html)

## Getting Help

We use Slack for real-time debugging, community updates, and general talk about ASDK. [Signup](http://asdk-slack-auto-invite.herokuapp.com) yourself or email AsyncDisplayKit(at)gmail.com to get an invite.

## Contributing

We welcome any contributions. See the [CONTRIBUTING](https://github.com/facebook/AsyncDisplayKit/blob/master/CONTRIBUTING.md) file for how to get involved.

## License

AsyncDisplayKit is BSD-licensed.  We also provide an additional patent grant. The files in the `/examples` directory are licensed under a separate license as specified in each file; documentation is licensed CC-BY-4.0.
