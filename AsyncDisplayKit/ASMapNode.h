//
//  ASMapNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASImageNode.h>
#if TARGET_OS_IOS
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMapNode : ASImageNode

/**
 The current options of ASMapNode. This can be set at any time and ASMapNode will animate the change.<br><br>This property may be set from a background thread before the node is loaded, and will automatically be applied to define the behavior of the static snapshot (if .liveMap = NO) or the internal MKMapView (otherwise).<br><br> Changes to the region and camera options will only be animated when when the liveMap mode is enabled, otherwise these options will be applied statically to the new snapshot. <br><br> The options object is used to specify properties even when the liveMap mode is enabled, allowing seamless transitions between the snapshot and liveMap (as well as back to the snapshot).
 */
@property (nonatomic, strong) MKMapSnapshotOptions *options;

/** The region is simply the sub-field on the options object.  If the objects object is reset,
    this will in effect be overwritten and become the value of the .region property on that object.
    Defaults to MKCoordinateRegionForMapRect(MKMapRectWorld).
 */
@property (nonatomic, assign) MKCoordinateRegion region;

/**
 This is the MKMapView that is the live map part of ASMapNode. This will be nil if .liveMap = NO. Note, MKMapView is *not* thread-safe.
 */
@property (nullable, nonatomic, readonly) MKMapView *mapView;

/**
 Set this to YES to turn the snapshot into an interactive MKMapView and vice versa. Defaults to NO. This property may be set on a background thread before the node is loaded, and will automatically be actioned, once the node is loaded. 
 */
@property (nonatomic, assign, getter=isLiveMap) BOOL liveMap;

/**
 @abstract Whether ASMapNode should automatically request a new map snapshot to correspond to the new node size.
 @default Default value is YES.
 @discussion If mapSize is set then this will be set to NO, since the size will be the same in all orientations.
 */
@property (nonatomic, assign) BOOL needsMapReloadOnBoundsChange;

/**
 Set the delegate of the MKMapView. This can be set even before mapView is created and will be set on the map in the case that the liveMap mode is engaged.
 */
@property (nonatomic, weak) id <MKMapViewDelegate> mapDelegate;

/**
 * @abstract The annotations to display on the map.
 */
@property (nonatomic, copy) NSArray<id<MKAnnotation>> *annotations;

@end

NS_ASSUME_NONNULL_END

#endif