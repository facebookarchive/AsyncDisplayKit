/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <MapKit/MapKit.h>
@interface ASMapNode : ASControlNode
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) ASImageNode *mapImage;
@property (nonatomic, readonly) ASDisplayNode *liveMap;
/**
 Whether the map snapshot should turn into a MKMapView when tapped on. Defaults to YES.
 */
@property (nonatomic, assign) BOOL hasLiveMap;
/**
 @abstract Explicitly set the size of the map and therefore the size of ASMapNode. Defaults to CGSizeMake(constrainedSize.max.width, 256).
 @discussion If the mapSize width or height is greater than the available space, then ASMapNode will take the maximum space available.
 @result The current size of the ASMapNode.
 */
@property (nonatomic, assign) CGSize mapSize;
/**
 @abstract Whether ASMapNode should automatically request a new map snapshot to correspond to the new node size. Defaults to YES.
 @discussion If mapSize is set then this will be set to NO, since the size will be the same in all orientations.
 */
@property (nonatomic, assign) BOOL automaticallyReloadsMapImageOnOrientationChange;
/**
 Set the delegate of the MKMapView.
 */
@property (nonatomic, weak) id <MKMapViewDelegate> mapDelegate;
/**
 * @discussion This method adds annotations to the static map view and also to the live map view.
 * @param annotations An array of objects that conform to the MKAnnotation protocol
 */
- (void)addAnnotations:(NSArray *)annotations;
@end
