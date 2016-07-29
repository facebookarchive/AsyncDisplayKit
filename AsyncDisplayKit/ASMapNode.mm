//
//  ASMapNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if TARGET_OS_IOS
#import "ASMapNode.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeExtras.h"
#import "ASInsetLayoutSpec.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"

@interface ASMapNode()
{
  MKMapSnapshotter *_snapshotter;
  BOOL _snapshotAfterLayout;
  NSArray *_annotations;
}
@end

@implementation ASMapNode

@synthesize needsMapReloadOnBoundsChange = _needsMapReloadOnBoundsChange;
@synthesize mapDelegate = _mapDelegate;
@synthesize options = _options;
@synthesize liveMap = _liveMap;
@synthesize showAnnotationsOptions = _showAnnotationsOptions;

#pragma mark - Lifecycle
- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  self.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  self.clipsToBounds = YES;
  self.userInteractionEnabled = YES;
  
  _needsMapReloadOnBoundsChange = YES;
  _liveMap = NO;
  _annotations = @[];
  _showAnnotationsOptions = ASMapNodeShowAnnotationsOptionsIgnored;
  return self;
}

- (void)didLoad
{
  [super didLoad];
  if (self.isLiveMap) {
    [self addLiveMap];
  }
}

- (void)dealloc
{
  [self destroySnapshotter];
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
  ASDN::MutexLocker l(__instanceLock__);
  return _liveMap;
}

- (void)setLiveMap:(BOOL)liveMap
{
  ASDisplayNodeAssert(!self.isLayerBacked, @"ASMapNode can not use the interactive map feature whilst .isLayerBacked = YES, set .layerBacked = NO to use the interactive map feature.");
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);
  return _needsMapReloadOnBoundsChange;
}

- (void)setNeedsMapReloadOnBoundsChange:(BOOL)needsMapReloadOnBoundsChange
{
  ASDN::MutexLocker l(__instanceLock__);
  _needsMapReloadOnBoundsChange = needsMapReloadOnBoundsChange;
}

- (MKMapSnapshotOptions *)options
{
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);
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
  MKMapSnapshotOptions * options = [self.options copy];
  options.region = region;
  self.options = options;
}

#pragma mark - Snapshotter

static BOOL _hasCreatedPinProperties;

+ (MKAnnotationView *)pin
{
  static dispatch_once_t onceToken;
  static MKAnnotationView *__pin = nil;
  dispatch_once(&onceToken, ^{
    ASDisplayNodeAssertMainThread();
    __pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
  });
  return __pin;
}

+ (UIImage *)pinImage
{
  static dispatch_once_t onceToken;
  static UIImage *__pinImage = nil;
  dispatch_once(&onceToken, ^{
    ASDisplayNodeAssertMainThread();
    __pinImage = self.pin.image;
  });
  return __pinImage;
}

+ (CGPoint)pinCenterOffset
{
  static dispatch_once_t onceToken;
  static CGPoint __pinCenterOffset;
  dispatch_once(&onceToken, ^{
    ASDisplayNodeAssertMainThread();
    __pinCenterOffset = self.pin.centerOffset;
  });
  return __pinCenterOffset;
}

- (void)takeSnapshot
{
  // If our size is zero, we want to avoid calling a default sized snapshot. Set _snapshotAfterLayout to YES
  // so if layout changes in the future, we'll try snapshotting again.
  ASLayout *layout = self.calculatedLayout;
  if (layout == nil || CGSizeEqualToSize(CGSizeZero, layout.size)) {
    _snapshotAfterLayout = YES;
    return;
  }
  
  _snapshotAfterLayout = NO;
  
  if (!_snapshotter) {
    [self setUpSnapshotter];
  }
  
  if (_snapshotter.isLoading) {
    return;
  }

  __weak __typeof__(self) weakSelf = self;
  dispatch_queue_t snapshotQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  [_snapshotter startWithQueue:snapshotQueue
             completionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
                 __typeof__(self) strongSelf = weakSelf;
                if (!strongSelf) {
                  return;
                }
                 
                if (!error) {
                  UIImage *image = snapshot.image;
                  NSArray *annotations = strongSelf.annotations;
                  if (annotations.count > 0) {
                    // Only create a graphics context if we have annotations to draw.
                    // The MKMapSnapshotter is currently not capable of rendering annotations automatically.
                    
                    __block UIImage *pinImage;
                    __block CGSize pinSize;
                    __block CGPoint pinCenterOffset;
                    
                    void (^drawAnnotationsBlock)(void) = ^{
                      CGRect finalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
                          
                      UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
                      [image drawAtPoint:CGPointZero];
                          
                      for (id<MKAnnotation> annotation in annotations) {
                        CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
                        if (CGRectContainsPoint(finalImageRect, point)) {
                          point.x -= pinSize.width / 2.0;
                          point.y -= pinSize.height / 2.0;
                          point.x += pinCenterOffset.x;
                          point.y += pinCenterOffset.y;
                          [pinImage drawAtPoint:point];
                        }
                      }
                          
                      UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
                      UIGraphicsEndImageContext();
                      strongSelf.image = finalImage;
                    };
                    
                    // Get a standard annotation view pin. Future implementations should use a custom annotation image property.
                    if (_hasCreatedPinProperties)
                    {
                      pinImage = [ASMapNode pinImage];
                      pinSize = pinImage.size;
                      pinCenterOffset = [ASMapNode pinCenterOffset];
                      drawAnnotationsBlock();
                    }
                    else
                    {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        pinImage = [ASMapNode pinImage];
                        pinSize = pinImage.size;
                        pinCenterOffset = [ASMapNode pinCenterOffset];
                        _hasCreatedPinProperties = true;
                        
                        dispatch_async(snapshotQueue, drawAnnotationsBlock);
                      });
                    }
                  }
                  else {
                    strongSelf.image = image;
                  }
                }
  }];
}

- (void)setUpSnapshotter
{
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

    ASMapNodeShowAnnotationsOptions showAnnotationsOptions = self.showAnnotationsOptions;
    if (showAnnotationsOptions & ASMapNodeShowAnnotationsOptionsZoomed) {
      BOOL const animated = showAnnotationsOptions & ASMapNodeShowAnnotationsOptionsAnimated;
      [_mapView showAnnotations:_mapView.annotations animated:animated];
    }
  }
}

- (void)removeLiveMap
{
  [_mapView removeFromSuperview];
  _mapView = nil;
}

- (NSArray *)annotations
{
  ASDN::MutexLocker l(__instanceLock__);
  return _annotations;
}

- (void)setAnnotations:(NSArray *)annotations
{
  annotations = [annotations copy] ? : @[];

  ASDN::MutexLocker l(__instanceLock__);
  _annotations = annotations;
  ASMapNodeShowAnnotationsOptions showAnnotationsOptions = self.showAnnotationsOptions;
  BOOL showZoomed = showAnnotationsOptions & ASMapNodeShowAnnotationsOptionsZoomed;
  if (self.isLiveMap) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_mapView removeAnnotations:_mapView.annotations];
      [_mapView addAnnotations:annotations];

      if (showZoomed) {
        BOOL const animated = showAnnotationsOptions & ASMapNodeShowAnnotationsOptionsAnimated;
        [_mapView showAnnotations:_mapView.annotations animated:animated];
      }
    });
  } else {
    if (showZoomed) {
      self.region = [self regionToFitAnnotations:annotations];
    }
    else {
      [self takeSnapshot];
    }
  }
}

-(MKCoordinateRegion)regionToFitAnnotations:(NSArray<id<MKAnnotation>> *)annotations
{
  if([annotations count] == 0)
    return MKCoordinateRegionForMapRect(MKMapRectWorld);

  CLLocationCoordinate2D topLeftCoord = CLLocationCoordinate2DMake(-90, 180);
  CLLocationCoordinate2D bottomRightCoord = CLLocationCoordinate2DMake(90, -180);

  for (id<MKAnnotation> annotation in annotations) {
    topLeftCoord = CLLocationCoordinate2DMake(fmax(topLeftCoord.latitude, annotation.coordinate.latitude),
                                              fmin(topLeftCoord.longitude, annotation.coordinate.longitude));
    bottomRightCoord = CLLocationCoordinate2DMake(fmin(bottomRightCoord.latitude, annotation.coordinate.latitude),
                                                  fmax(bottomRightCoord.longitude, annotation.coordinate.longitude));
  }

  MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(topLeftCoord.latitude - (topLeftCoord.latitude - bottomRightCoord.latitude) * 0.5,
                                                                                topLeftCoord.longitude + (bottomRightCoord.longitude - topLeftCoord.longitude) * 0.5),
                                                     MKCoordinateSpanMake(fabs(topLeftCoord.latitude - bottomRightCoord.latitude) * 2,
                                                                          fabs(bottomRightCoord.longitude - topLeftCoord.longitude) * 2));

  return region;
}

-(ASMapNodeShowAnnotationsOptions)showAnnotationsOptions {
  ASDN::MutexLocker l(__instanceLock__);
  return _showAnnotationsOptions;
}

-(void)setShowAnnotationsOptions:(ASMapNodeShowAnnotationsOptions)showAnnotationsOptions {
  ASDN::MutexLocker l(__instanceLock__);
  _showAnnotationsOptions = showAnnotationsOptions;
}

#pragma mark - Layout
- (void)setSnapshotSizeWithReloadIfNeeded:(CGSize)snapshotSize
{
  if (snapshotSize.height > 0 && snapshotSize.width > 0 && !CGSizeEqualToSize(self.options.size, snapshotSize)) {
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
    
    // FIXME: Need a better way to allow maps to take up the right amount of space in a layout (sizeRange, etc)
    // These fallbacks protect against inheriting a constrainedSize that contains a CGFLOAT_MAX value.
    if (!isValidForLayout(size.width)) {
      size.width = 100.0;
    }
    if (!isValidForLayout(size.height)) {
      size.height = 100.0;
    }
  }
  [self setSnapshotSizeWithReloadIfNeeded:size];
  return size;
}

- (void)calculatedLayoutDidChange
{
  [super calculatedLayoutDidChange];
  
  if (_snapshotAfterLayout) {
    [self takeSnapshot];
  }
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