/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASImageNode.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMapNode : ASImageNode

/**
 The current region of ASMapNode. This can be set at any time and ASMapNode will animate the change. This property may be set from a background thread before the node is loaded, and will automatically be applied to define the region of the static snapshot (if .liveMap = NO) or the internal MKMapView (otherwise).
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
 @abstract Whether ASMapNode should automatically request a new map snapshot to correspond to the new node size. Defaults to YES.
 @discussion If mapSize is set then this will be set to NO, since the size will be the same in all orientations.
 */
@property (nonatomic, assign) BOOL needsMapReloadOnBoundsChange;

/**
 Set the delegate of the MKMapView. This can be set even before mapView is created and will be set on the map in the case that the liveMap mode is engaged.
 */
@property (nonatomic, weak) id <MKMapViewDelegate> mapDelegate;

/**
 * @discussion This method set the annotations of the static map view and also to the live map view. Passing an empty array clears the map of any annotations.
 * @param annotations An array of objects that conform to the MKAnnotation protocol
 */
- (void)setAnnotations:(NSArray<id<MKAnnotation>> *)annotations;

@end

NS_ASSUME_NONNULL_END
