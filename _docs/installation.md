---
title: Installation
layout: docs
permalink: /docs/installation.html
prevPage: resources.html
nextPage: upgrading.html
---

AsyncDisplayKit may be added to your project via <a href = "installation.html#cocoapods">CocoaPods</a> or <a href = "installation.html#carthage-standard-build">Carthage</a> (standard build)</li>. Do not forget to import the framework header 

```
#import <AsyncDisplayKit/AsyncDisplayKit.h>
```
or create a <a href="https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html">Objective-C bridging header</a> (Swift).

If you have any problems installing AsyncDisplayKit, please contact us on Github or <a href = "/docs/resources.html#slack">Slack</a>!

## CocoaPods

AsyncDisplayKit is available on <a href="https://cocoapods.org/pods/AsyncDisplayKit">CocoaPods</a>. Add the following to your Podfile:

```
target 'MyApp' do
	pod "AsyncDisplayKit"
end
```

Quit Xcode completely before running 

```
> pod install
```

in the project directory in Terminal.  

To update your version of AsyncDisplayKit, run 

```
> pod update AsyncDisplayKit
```

in the project directory in Terminal. 

Don't forget to use the workspace `.xcworkspace` file, _not_ the project `.xcodeproj` file.

## Carthage (standard build)

<div class = "note">
The standard way to use Carthage is to have a Cartfile list the dependencies, and then run <code>carthage update</code> to download the dependenices into the <code>Cathage/Checkouts</code> folder and build each of those into frameworks located in the <code>Carthage/Build</code> folder, and finally the developer has to manually integrate in the project.
</div>

AsyncDisplayKit is also available through <a href="https://github.com/Carthage/Carthage">Carthage</a>. 

Add the following to your Cartfile to get the **latest release** branch:

```
github "facebook/AsyncDisplayKit"
```

Or, to get the **master** branch:

```
github "facebook/AsyncDisplayKit" "master"
```

AsyncDisplayKit has its own Cartfile which lists its dependencies, so this is the only line you will need to include in your Cartfile. 

Run 

```
> carthage update
```

in Terminal. This will fetch dependencies into a `Carthage/Checkouts` folder, then build each one. 

Look for terminal output confirming `AsyncDisplayKit`, `PINRemoteImage (3.0.0-beta.2)` and `PINCache` are all fetched and built. The ASDK framework Cartfile should handle the dependencies correctly. 

In Xcode, on your application targets’ **“General”** settings tab, in the **“Linked Frameworks and Libraries”** section, drag and drop each framework you want to use from the `Carthage/Build` folder on disk.

## Carthage (light)

AsyncDisplayKit does not yet support the lighter way of using Carthage, in which you manually add the project files. This is because one of its dependencies, PINCache (a nested dependency of PINRemoteImage) does not yet have a project file. 

Without including PINRemoteImage and PINCache, you will not get AsyncDisplayKit's full image feature set. 
