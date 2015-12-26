/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASMapNode.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>
#import <AsyncDisplayKit/ASThread.h>

@interface ASMapNode()
{
  ASDN::RecursiveMutex _propertyLock;
  MKMapSnapshotter *_snapshotter;
  MKMapSnapshotOptions *_options;
  NSArray *_annotations;
  CLLocationCoordinate2D _centerCoordinateOfMap;
}
@end

@implementation ASMapNode

@synthesize needsMapReloadOnBoundsChange = _needsMapReloadOnBoundsChange;
@synthesize mapDelegate = _mapDelegate;
@synthesize region = _region;
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
  
  //Default world-scale view
  _region = MKCoordinateRegionForMapRect(MKMapRectWorld);
  
  _options = [[MKMapSnapshotOptions alloc] init];
  _options.region = _region;
  
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
  if (self.isLiveMap) {
    [self addLiveMap];
  } else {
    [self takeSnapshot];
  }
}

- (void)clearContents
{
  [super clearContents];
  if (self.isLiveMap) {
    [self removeLiveMap];
  }
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

- (MKCoordinateRegion)region
{
  ASDN::MutexLocker l(_propertyLock);
  return _region;
}

- (void)setRegion:(MKCoordinateRegion)region
{
  ASDN::MutexLocker l(_propertyLock);
  _region = region;
  if (self.isLiveMap) {
    [_mapView setRegion:_region animated:YES];
  } else {
    _options.region = _region;
    [self resetSnapshotter];
    [self takeSnapshot];
  }
}

#pragma mark - Snapshotter

- (void)takeSnapshot
{
  if (!_snapshotter) {
    [self setUpSnapshotter];
  }
  [_snapshotter cancel];
  [_snapshotter startWithCompletionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
    if (!error) {
      UIImage *image = snapshot.image;
      CGRect finalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
      
      UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
      [image drawAtPoint:CGPointMake(0, 0)];
      
      if (_annotations.count > 0 ) {
        // Get a standard annotation view pin. Future implementations should use a custom annotation image property.
        MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
        UIImage *pinImage = pin.image;
        for (id<MKAnnotation>annotation in _annotations)
        {
          CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
          if (CGRectContainsPoint(finalImageRect, point))
          {
            CGPoint pinCenterOffset = pin.centerOffset;
            point.x -= pin.bounds.size.width / 2.0;
            point.y -= pin.bounds.size.height / 2.0;
            point.x += pinCenterOffset.x;
            point.y += pinCenterOffset.y;
            [pinImage drawAtPoint:point];
          }
        }
      }
      
      UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      self.image = finalImage;
    }
  }];
}

- (void)setUpSnapshotter
{
  ASDisplayNodeAssert(!CGSizeEqualToSize(CGSizeZero, self.calculatedSize), @"self.calculatedSize can not be zero. Make sure that you are setting a preferredFrameSize or wrapping ASMapNode in a ASRatioLayoutSpec or similar.");
  _options.size = self.calculatedSize;
  _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
}

- (void)resetSnapshotter
{
  [_snapshotter cancel];
  _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
}

#pragma mark - Actions
- (void)addLiveMap
{
  ASDisplayNodeAssertMainThread();
  if (!_mapView) {
    __weak ASMapNode *weakSelf = self;
    _mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    _mapView.delegate = weakSelf.mapDelegate;
    [_mapView setRegion:_options.region];
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
  _centerCoordinateOfMap = _mapView.centerCoordinate;
  [_mapView removeFromSuperview];
  _mapView = nil;
}

- (void)setAnnotations:(NSArray *)annotations
{
  ASDN::MutexLocker l(_propertyLock);
  _annotations = [annotations copy];
  if (self.isLiveMap) {
    [_mapView removeAnnotations:_mapView.annotations];
    [_mapView addAnnotations:annotations];
  } else {
    [self takeSnapshot];
  }
}

#pragma mark - Layout
// Layout isn't usually needed in the box model, but since we are making use of MKMapView which is hidden in an ASDisplayNode this is preferred.
- (void)layout
{
  [super layout];
  if (self.isLiveMap) {
    _mapView.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height);
  } else {
    // If our bounds.size is different from our current snapshot size, then let's request a new image from MKMapSnapshotter.
    if (!CGSizeEqualToSize(_options.size, self.bounds.size) && _needsMapReloadOnBoundsChange) {
      _options.size = self.bounds.size;
      [self resetSnapshotter];
      [self takeSnapshot];
    }
  }
}
@end