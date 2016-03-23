/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#if TARGET_OS_IOS
#import "ASMapNode.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@interface ASMapNode()
{
  ASDN::RecursiveMutex _propertyLock;
  MKMapSnapshotter *_snapshotter;
  NSArray *_annotations;
  CLLocationCoordinate2D _centerCoordinateOfMap;
}
@end

@implementation ASMapNode

@synthesize needsMapReloadOnBoundsChange = _needsMapReloadOnBoundsChange;
@synthesize mapDelegate = _mapDelegate;
@synthesize options = _options;
@synthesize liveMap = _liveMap;

#pragma mark - Lifecycle
- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  self.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  self.clipsToBounds = YES;
  
  _needsMapReloadOnBoundsChange = YES;
  _liveMap = NO;
  _centerCoordinateOfMap = kCLLocationCoordinate2DInvalid;
  _annotations = @[];
  return self;
}

- (void)didLoad
{
  [super didLoad];
  if (self.isLiveMap) {
    self.userInteractionEnabled = YES;
    [self addLiveMap];
  }
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  ASDisplayNodeAssert(!self.isLiveMap, @"ASMapNode can not be layer backed whilst .liveMap = YES, set .liveMap = NO to use layer backing.");
  [super setLayerBacked:layerBacked];
}

- (void)fetchData
{
  [super fetchData];
  ASPerformBlockOnMainThread(^{
    if (self.isLiveMap) {
      [self addLiveMap];
    } else {
      [self takeSnapshot];
    }
  });
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  ASPerformBlockOnMainThread(^{
    if (self.isLiveMap) {
      [self removeLiveMap];
    }
  });
}

#pragma mark - Settings

- (BOOL)isLiveMap
{
  ASDN::MutexLocker l(_propertyLock);
  return _liveMap;
}

- (void)setLiveMap:(BOOL)liveMap
{
  ASDisplayNodeAssert(!self.isLayerBacked, @"ASMapNode can not use the interactive map feature whilst .isLayerBacked = YES, set .layerBacked = NO to use the interactive map feature.");
  ASDN::MutexLocker l(_propertyLock);
  if (liveMap == _liveMap) {
    return;
  }
  _liveMap = liveMap;
  if (self.nodeLoaded) {
    liveMap ? [self addLiveMap] : [self removeLiveMap];
  }
}

- (BOOL)needsMapReloadOnBoundsChange
{
  ASDN::MutexLocker l(_propertyLock);
  return _needsMapReloadOnBoundsChange;
}

- (void)setNeedsMapReloadOnBoundsChange:(BOOL)needsMapReloadOnBoundsChange
{
  ASDN::MutexLocker l(_propertyLock);
  _needsMapReloadOnBoundsChange = needsMapReloadOnBoundsChange;
}

- (MKMapSnapshotOptions *)options
{
  ASDN::MutexLocker l(_propertyLock);
  if (!_options) {
    _options = [[MKMapSnapshotOptions alloc] init];
    _options.region = MKCoordinateRegionForMapRect(MKMapRectWorld);
    CGSize calculatedSize = self.calculatedSize;
    if (!CGSizeEqualToSize(calculatedSize, CGSizeZero)) {
      _options.size = calculatedSize;
    }
  }
  return _options;
}

- (void)setOptions:(MKMapSnapshotOptions *)options
{
  ASDN::MutexLocker l(_propertyLock);
  if (!_options || ![options isEqual:_options]) {
    _options = options;
    if (self.isLiveMap) {
      [self applySnapshotOptions];
    } else if (_snapshotter) {
      [self destroySnapshotter];
      [self takeSnapshot];
    }
  }
}

- (MKCoordinateRegion)region
{
  return self.options.region;
}

- (void)setRegion:(MKCoordinateRegion)region
{
  self.options.region = region;
}

#pragma mark - Snapshotter

- (void)takeSnapshot
{
  if (!_snapshotter) {
    [self setUpSnapshotter];
  }
  
  if (_snapshotter.isLoading) {
    return;
  }

  [_snapshotter startWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
             completionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
                if (!error) {
                  UIImage *image = snapshot.image;
                  
                  if (_annotations.count > 0) {
                    // Only create a graphics context if we have annotations to draw.
                    // The MKMapSnapshotter is currently not capable of rendering annotations automatically.
                    
                    CGRect finalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
                    
                    UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
                    [image drawAtPoint:CGPointZero];
                    
                    // Get a standard annotation view pin. Future implementations should use a custom annotation image property.
                    MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
                    UIImage *pinImage = pin.image;
                    CGSize pinSize = pin.bounds.size;
                    
                    for (id<MKAnnotation> annotation in _annotations) {
                      CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
                      if (CGRectContainsPoint(finalImageRect, point)) {
                        CGPoint pinCenterOffset = pin.centerOffset;
                        point.x -= pinSize.width / 2.0;
                        point.y -= pinSize.height / 2.0;
                        point.x += pinCenterOffset.x;
                        point.y += pinCenterOffset.y;
                        [pinImage drawAtPoint:point];
                      }
                    }
                    
                    image = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                  }
                  
                  self.image = image;
                }
  }];
}

- (void)setUpSnapshotter
{
  ASDisplayNodeAssert(!CGSizeEqualToSize(CGSizeZero, self.calculatedSize), @"self.calculatedSize can not be zero. Make sure that you are setting a preferredFrameSize or wrapping ASMapNode in a ASRatioLayoutSpec or similar.");
  _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:self.options];
}

- (void)destroySnapshotter
{
  [_snapshotter cancel];
  _snapshotter = nil;
}

- (void)applySnapshotOptions
{
  MKMapSnapshotOptions *options = self.options;
  [_mapView setCamera:options.camera animated:YES];
  [_mapView setRegion:options.region animated:YES];
  [_mapView setMapType:options.mapType];
  _mapView.showsBuildings = options.showsBuildings;
  _mapView.showsPointsOfInterest = options.showsPointsOfInterest;
}

#pragma mark - Actions
- (void)addLiveMap
{
  ASDisplayNodeAssertMainThread();
  if (!_mapView) {
    __weak ASMapNode *weakSelf = self;
    _mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    _mapView.delegate = weakSelf.mapDelegate;
    [weakSelf applySnapshotOptions];
    [_mapView addAnnotations:_annotations];
    [weakSelf setNeedsLayout];
    [weakSelf.view addSubview:_mapView];
    
    if (CLLocationCoordinate2DIsValid(_centerCoordinateOfMap)) {
      [_mapView setCenterCoordinate:_centerCoordinateOfMap];
    }
  }
}

- (void)removeLiveMap
{
  // FIXME: With MKCoordinateRegion, isn't the center coordinate fully specified?  Do we need this?
  _centerCoordinateOfMap = _mapView.centerCoordinate;
  [_mapView removeFromSuperview];
  _mapView = nil;
}

- (NSArray *)annotations
{
  ASDN::MutexLocker l(_propertyLock);
  return _annotations;
}

- (void)setAnnotations:(NSArray *)annotations
{
  annotations = [annotations copy] ? : @[];

  ASDN::MutexLocker l(_propertyLock);
  _annotations = annotations;
  if (self.isLiveMap) {
    [_mapView removeAnnotations:_mapView.annotations];
    [_mapView addAnnotations:annotations];
  } else {
    [self takeSnapshot];
  }
}

#pragma mark - Layout
- (void)setSnapshotSizeWithReloadIfNeeded:(CGSize)snapshotSize
{
  if (!CGSizeEqualToSize(self.options.size, snapshotSize)) {
    _options.size = snapshotSize;
    if (_snapshotter) {
      [self destroySnapshotter];
      [self takeSnapshot];
    }
  }
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  CGSize size = self.preferredFrameSize;
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    size = constrainedSize;
  }
  [self setSnapshotSizeWithReloadIfNeeded:size];
  return constrainedSize;
}

// -layout isn't usually needed over -layoutSpecThatFits, but this way we can avoid a needless node wrapper for MKMapView.
- (void)layout
{
  [super layout];
  if (self.isLiveMap) {
    _mapView.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height);
  } else {
    // If our bounds.size is different from our current snapshot size, then let's request a new image from MKMapSnapshotter.
    if (_needsMapReloadOnBoundsChange) {
      [self setSnapshotSizeWithReloadIfNeeded:self.bounds.size];
      // FIXME: Adding a check for FetchData here seems to cause intermittent map load failures, but shouldn't.
      // if (ASInterfaceStateIncludesFetchData(self.interfaceState)) {
    }
  }
}
@end
#endif