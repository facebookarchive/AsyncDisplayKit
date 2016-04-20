---
title: Installation
layout: docs
permalink: /docs/installation.html
next: references.html
---
###CocoaPods
AsyncDisplayKit is available on <a href="http://cocoapods.org">CocoaPods</a>.  Add the following to your Podfile:
 ```objective-c
pod 'AsyncDisplayKit'
```
###Carthage
AsyncDisplayKit is also available through <a href="https://github.com/Carthage/Carthage">Carthage</a>. Add the following to your Cartfile:
 ```objective-c
github "facebook/AsyncDisplayKit"
```
Run ‘carthage update’ in Terminal and to fetch and build the AsyncDisplayKit library. This will create a folder named Carthage in your app’s root folder. In that folder there will be a ‘Build’ folder from where you have to drag the frameworks you want to use into the “Linked Frameworks and Libraries” section in Xcode.
###Static Library
AsyncDisplayKit can also be used as a regular static library
Copy the project to your codebase manually, adding `AsyncDisplayKit.xcodeproj` to your workspace. Add `libAsyncDisplayKit.a`, AssetsLibrary, and Photos to the "Link Binary With Libraries" build phase. Include `-lc++ -ObjC` in your project linker flags.
###Importing AsyncDisplayKit
Import the framework header, or create an <a href="https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html">Objective-C bridging header</a> if you're using **Swift**:
 ```objective-c
#import <AsyncDisplayKit/AsyncDisplayKit.h>
```
