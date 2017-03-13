---
title: ASMapNode
layout: docs
permalink: /docs/map-node.html
prevPage: video-node.html
nextPage: control-node.html
---

`ASMapNode` allows you to easily specify a geographic region to show to your users.  

### Basic Usage

Let's say you'd like to show a snapshot of San Francisco.  All you need are the coordinates.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
ASMapNode *mapNode = [[ASMapNode alloc] init];
mapNode.preferredFrameSize = CGSizeMake(300.0, 300.0);

// San Francisco
CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(37.7749, -122.4194);

// show 20,000 square meters
mapNode.region = MKCoordinateRegionMakeWithDistance(coord, 20000, 20000);
</pre>

<pre lang="swift" class = "swiftCode hidden">
let mapNode = ASMapNode()
mapNode.preferredFrameSize = CGSize(width: 300.0, height: 300.0)

// San Francisco
let coord = CLLocationCoordinate2DMake(37.7749, -122.4194)

// show 20,000 square meters
mapNode.region = MKCoordinateRegionMakeWithDistance(coord, 20000, 20000)
</pre>
</div>
</div>

<img width = "300" src = "/static/images/basicMap.png"/>

The region value is actually just one piece of a property called `options` of type `MKMapSnapshotOptions`.


### MKMapSnapshotOptions

A map node's main components can be defined directly through its `options` property.  The snapshot options object contains the following:

<ul>
	<li>An <code>MKMapCamera</code>: used to configure altitude and pitch of the camera</li>
	<li>An <code>MKMapRect</code>: basically a CGRect</li>
	<li>An <code>MKMapRegion</code>: Controls the coordinate of focus, and the size around that focus to show</li>
	<li>An <code>MKMapType</code>: Can be set to Standard, Satellite, etc.</li>
</ul>

To do something like changing your map to a satellite map, you just need to create an options object and set its properties accordingly.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];
options.mapType = MKMapTypeSatellite;
options.region = MKCoordinateRegionMakeWithDistance(coord, 20000, 20000);

mapNode.options = options;
</pre>
<pre lang="swift" class = "swiftCode hidden">
let options = MKMapSnapshotOptions()
options.mapType = .Satellite
options.region = MKCoordinateRegionMakeWithDistance(coord, 20000, 20000)

mapNode.options = options
</pre>
</div>
</div>

Results in:

<img width = "300" src = "/static/images/satelliteMap.png"/>

One thing to note is that setting the options value will overwrite a previously set region.

### Annotations

To set annotations, all you need to do is assign an array of annotations to your `ASMapNode`.

Say you want to show a pin directly in the middle of your map of San Francisco.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
annotation.coordinate = CLLocationCoordinate2DMake(37.7749, -122.4194);

mapNode.annotations = @[annotation];
</pre>
<pre lang="swift" class = "swiftCode hidden">
let annotation = MKPointAnnotation()
annotation.coordinate = CLLocationCoordinate2DMake(37.7749, -122.4194)

mapNode.annotations = [annotation]
</pre>
</div>
</div>

<img width = "300" src = "/static/images/mapWithAnnotation.png"/>

No problem.

### Live Map Mode

Chaning your map node from a static view of some region, into a fully interactable cartographic playground is as easy as:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
mapNode.liveMap = YES;
</pre>
<pre lang="swift" class = "swiftCode hidden">
mapNode.liveMap = true
</pre>
</div>
</div>

This enables "live map mode" in which the node will use an <a href = "https://developer.apple.com/library/mac/documentation/MapKit/Reference/MKMapView_Class/">MKMapView</a> to render an interactive version of your map.

<img width = "300" src = "/static/images/liveMap.gif"/>

As with UIKit views, the `MKMapView` used in live map mode is not thread-safe.

### MKMapView Delegate

If live map mode has been enabled and you need to react to any events associated with the map node, you can set the `mapDelegate` property.  This delegate should conform to the <a href = "https://developer.apple.com/library/ios/documentation/MapKit/Reference/MKMapViewDelegate_Protocol/index.html">MKMapViewDelegate</a> protocol.




