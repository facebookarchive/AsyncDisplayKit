/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASMapNode.h"
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>
#import <AsyncDisplayKit/ASThread.h>

@interface ASMapNode()
{
  ASDN::RecursiveMutex _propertyLock;
  MKMapSnapshotter *_snapshotter;
  MKMapSnapshotOptions *_options;
  NSArray *_annotations;
  ASDisplayNode *_mapNode;
  CLLocationCoordinate2D _centerCoordinateOfMap;
}
@end

@implementation ASMapNode

@synthesize liveMap = _liveMap;
@synthesize needsMapReloadOnBoundsChange = _needsMapReloadOnBoundsChange;
@synthesize mapDelegate = _mapDelegate;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
  if (!(self = [super init])) {
    return nil;
  }
  self.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  self.clipsToBounds = YES;

  _needsMapReloadOnBoundsChange = YES;
  _liveMap = NO;
  _centerCoordinateOfMap = kCLLocationCoordinate2DInvalid;

  _options = [[MKMapSnapshotOptions alloc] init];
  _options.region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);;
  
  return self;
}

- (void)setAnnotations:(NSArray *)annotations
{
  ASDN::MutexLocker l(_propertyLock);
  _annotations = [annotations copy];
  if (annotations.count != _annotations.count) {
    // Redraw
    [self setNeedsDisplay];
  }
}

- (void)setUpSnapshotter
{
  if (!_snapshotter) {
    ASDisplayNodeAssert(!CGSizeEqualToSize(CGSizeZero, self.calculatedSize), @"self.calculatedSize can not be zero. Make sure that you are setting a preferredFrameSize or wrapping ASMapNode in a ASRatioLayoutSpec or similar.");
      _options.size = self.calculatedSize;
      _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
  }
}

- (BOOL)isLiveMap
{
  ASDN::MutexLocker l(_propertyLock);
  return _liveMap;
}

- (void)setLiveMap:(BOOL)liveMap
{
  ASDN::MutexLocker l(_propertyLock);
  if (liveMap == _liveMap) {
    return;
  }
  _liveMap = liveMap;
  liveMap ? [self addLiveMap] : [self removeLiveMap];
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

- (void)fetchData
{
  [super fetchData];
  if (_liveMap && !_mapNode) {
    [self addLiveMap];
  }
  else {
    [self setUpSnapshotter];
    [self takeSnapshot];
  }
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  [self removeLiveMap];
}

- (void)takeSnapshot
{
  if (!_snapshotter.isLoading) {
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
}

- (void)resetSnapshotter
{
  if (!_snapshotter.isLoading) {
    _options.size = self.calculatedSize;
    _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
  }
}

#pragma mark - Action
- (void)addLiveMap
{
  if (self.isNodeLoaded && !_mapNode) {
    _mapNode = [[ASDisplayNode alloc]initWithViewBlock:^UIView *{
      _mapView = [[MKMapView alloc]initWithFrame:CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height)];
      _mapView.delegate = _mapDelegate;
      [_mapView setRegion:_options.region];
      [_mapView addAnnotations:_annotations];
      return _mapView;
    }];
    [self addSubnode:_mapNode];
    
    if (CLLocationCoordinate2DIsValid(_centerCoordinateOfMap)) {
      [_mapView setCenterCoordinate:_centerCoordinateOfMap];
    }
  }
}

- (void)removeLiveMap
{
  if (_mapNode) {
    _centerCoordinateOfMap = _mapView.centerCoordinate;
    [_mapNode removeFromSupernode];
    _mapView = nil;
    _mapNode = nil;
  }
  self.image = nil;
}

#pragma mark - Layout
// Layout isn't usually needed in the box model, but since we are making use of MKMapView which is hidden in an ASDisplayNode this is preferred.
- (void)layout
{
  [super layout];
  if (_mapView) {
    _mapView.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height);
  }
  else {
    // If our bounds.size is different from our current snapshot size, then let's request a new image from MKMapSnapshotter.
    if (!CGSizeEqualToSize(_options.size, self.bounds.size)) {
      if (_needsMapReloadOnBoundsChange && self.image) {
        [self resetSnapshotter];
        [self takeSnapshot];
      }
    }
  }
}

@end
