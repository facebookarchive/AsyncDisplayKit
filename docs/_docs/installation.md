---
title: Installation
layout: docs
permalink: /docs/installation.html
prevPage: resources.html
nextPage: adoption-guide-2-0-beta1.html
---

AsyncDisplayKit may be added to your project via CocoaPods or Carthage. Do not forget to import the framework header:

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
#import <AsyncDisplayKit/AsyncDisplayKit.h>
</pre>
</div>
</div>

or create a <a href="https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html">Objective-C bridging header</a> (Swift). If you have any problems installing AsyncDisplayKit, please contact us on Github or <a href = "/slack.html">Slack</a>!

## CocoaPods

AsyncDisplayKit is available on <a href="https://cocoapods.org/pods/AsyncDisplayKit">CocoaPods</a>. Add the following to your Podfile:

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
target 'MyApp' do
	pod "AsyncDisplayKit"
end
</pre>
</div>
</div>

Quit Xcode completely before running 

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
> pod install
</pre>
</div>
</div>

in the project directory in Terminal.  

To update your version of AsyncDisplayKit, run 

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
> pod update AsyncDisplayKit
</pre>
</div>
</div>

in the project directory in Terminal. 

Don't forget to use the workspace `.xcworkspace` file, _not_ the project `.xcodeproj` file.

## Carthage (standard build)

<div class = "note">
The standard way to use Carthage is to have a Cartfile list the dependencies, and then run `carthage update` to download the dependenices into the `Cathage/Checkouts` folder and build each of those into frameworks located in the `Carthage/Build` folder, and finally the developer has to manually integrate in the project.
</div>

AsyncDisplayKit is also available through <a href="https://github.com/Carthage/Carthage">Carthage</a>. 

Add the following to your Cartfile to get the **latest release** branch:

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
github "facebook/AsyncDisplayKit"
</pre>
</div>
</div>

<br>
Or, to get the **master** branch:

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
github "facebook/AsyncDisplayKit" "master"
</pre>
</div>
</div>

<br>
AsyncDisplayKit has its own Cartfile which lists its dependencies, so this is the only line you will need to include in your Cartfile. 

Run 

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
> carthage update
</pre>
</div>
</div>

<br>
in Terminal. This will fetch dependencies into a `Carthage/Checkouts` folder, then build each one. 

Look for terminal output confirming `AsyncDisplayKit`, `PINRemoteImage (3.0.0-beta.2)` and `PINCache` are all fetched and built. The ASDK framework Cartfile should handle the dependencies correctly. 

In Xcode, on your application targets’ **“General”** settings tab, in the **“Linked Frameworks and Libraries”** section, drag and drop each framework you want to use from the `Carthage/Build` folder on disk.

## Carthage (light)

AsyncDisplayKit does not yet support the lighter way of using Carthage, in which you manually add the project files. This is because one of its dependencies, `PINCache` (a nested dependency of `PINRemoteImage`) does not yet have a project file. 

Without including `PINRemoteImage` and `PINCache`, you will not get AsyncDisplayKit's full image feature set. 
