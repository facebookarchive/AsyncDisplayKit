## Coming from AsyncDisplayKit? Learn more [here](https://medium.com/@Pinterest_Engineering/introducing-texture-a-new-home-for-asyncdisplaykit-e7c003308f50)

![Texture](https://github.com/texturegroup/texture/raw/master/docs/static/images/logo.png)

[![Apps Using](https://img.shields.io/cocoapods/at/Texture.svg?label=Apps%20Using%20Texture&colorB=28B9FE)](http://cocoapods.org/pods/Texture)
[![Downloads](https://img.shields.io/cocoapods/dt/Texture.svg?label=Total%20Downloads&colorB=28B9FE)](http://cocoapods.org/pods/Texture)

[![Platform](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS-orange.svg)](http://texturegroup.org)
[![Languages](https://img.shields.io/badge/languages-ObjC%20%7C%20Swift-orange.svg)](http://texturegroup.org)

[![Version](https://img.shields.io/cocoapods/v/Texture.svg)](http://cocoapods.org/pods/Texture)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-59C939.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Texture.svg)](https://github.com/texturegroup/texture/blob/master/LICENSE)

## Installation

Texture is available via CocoaPods or Carthage. See our [Installation](http://texturegroup.org/docs/installation.html) guide for instructions.

## Performance Gains

Texture's basic unit is the `node`. An ASDisplayNode is an abstraction over `UIView`, which in turn is an abstraction over `CALayer`. Unlike views, which can only be used on the main thread, nodes are thread-safe: you can instantiate and configure entire hierarchies of them in parallel on background threads.

To keep its user interface smooth and responsive, your app should render at 60 frames per second — the gold standard on iOS. This means the main thread has one-sixtieth of a second to push each frame. That's 16 milliseconds to execute all layout and drawing code! And because of system overhead, your code usually has less than ten milliseconds to run before it causes a frame drop.

Texture lets you move image decoding, text sizing and rendering, layout, and other expensive UI operations off the main thread, to keep the main thread available to respond to user interaction.

## Advanced Developer Features

As the framework has grown, many features have been added that can save developers tons of time by eliminating common boilerplate style structures common in modern iOS apps. If you've ever dealt with cell reuse bugs, tried to performantly preload data for a page or scroll style interface or even just tried to keep your app from dropping too many frames you can benefit from integrating Texture.

## Learn More

* Read the our [Getting Started](http://texturegroup.org/docs/getting-started.html) guide
* Get the [sample projects](https://github.com/texturegroup/texture/tree/master/examples)
* Browse the [API reference](http://texturegroup.org/appledocs.html)

## Getting Help

We use Slack for real-time debugging, community updates, and general talk about Texture. [Signup](http://asdk-slack-auto-invite.herokuapp.com) yourself or email textureframework@gmail.com to get an invite.

## Contributing

We welcome any contributions. See the [CONTRIBUTING](https://github.com/texturegroup/texture/blob/master/CONTRIBUTING.md) file for how to get involved.

## License

The Texture project was created by Pinterest as a continuation, under a different name and license, of the AsyncDisplayKit codebase originally developed by Facebook.  AsyncDisplayKit was originally released by Facebook under a BSD license and additional patent grant.  Those BSD and patent licenses govern use of code in Texture contributed prior to 4/13/2017 (the original AsyncDisplayKit code), and copies of the licenses are included in the root directory of this source tree for reference.  All code contributed to Texture after 4/13/2017 is released by Pinterest under an Apache 2.0 license.
