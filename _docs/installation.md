---
title: Installation
layout: docs
permalink: /docs/installation.html
prevPage: philosophy.html
nextPage: intelligent-preloading.html
---

### CocoaPods

AsyncDisplayKit is available on <a href="http://cocoapods.org">CocoaPods</a>.  Add the following to your Podfile:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="ruby" class = "active">Ruby</a></span>

<div class = "code">
	<pre lang="ruby" class="ruby">
pod 'AsyncDisplayKit'
	</pre>
</div>
</div>


### Carthage

AsyncDisplayKit is also available through <a href="https://github.com/Carthage/Carthage">Carthage</a>. Add the following to your Cartfile:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="carthage" class = "active">Carthage</a></span>
<div class = "code">
	<pre lang="carthage" class="carthage">
github "facebook/AsyncDisplayKit"
	</pre>
</div>
</div>

Run ‘carthage update’ in Terminal and to fetch and build the AsyncDisplayKit library. This will create a folder named Carthage in your app’s root folder. In that folder there will be a ‘Build’ folder from where you have to drag the frameworks you want to use into the “Linked Frameworks and Libraries” section in Xcode.

### Static Library

AsyncDisplayKit can also be used as a regular static library
<ol>
<li>Copy the project to your codebase manually, adding `AsyncDisplayKit.xcodeproj` to your workspace.</li>
<li>In "Build Phases", add the AsyncDisplayKit Library to the list of "Target Dependencies".</li>
<li>In "Build Phases", add `libAsyncDisplayKit.a`, AssetsLibrary, and Photos to the "Link Binary With Libraries" list.</li>
<li>In "Build Settings", include `-lc++ -ObjC` in your project linker flags.</li>
</ol>

###Importing AsyncDisplayKit
Import the framework header, or create an <a href="https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html">Objective-C bridging header</a> if you're using **Swift**:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
	<pre lang="objc" class="objc">
#import &lt;AsyncDisplayKit/AsyncDisplayKit.h&gt;
	</pre>
</div>
</div>
