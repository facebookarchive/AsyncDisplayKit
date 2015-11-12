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
    CGSize _nodeSize;
    MKMapSnapshotter *_snapshotter;
    MKMapSnapshotOptions *_options;
    CGSize _maxSize;
    NSArray *_annotations;
}
@end

@implementation ASMapNode

@synthesize hasLiveMap = _hasLiveMap;
@synthesize mapSize = _mapSize;
@synthesize automaticallyReloadsMapImageOnOrientationChange = _automaticallyReloadsMapImageOnOrientationChange;
@synthesize mapDelegate = _mapDelegate;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
  if (!(self = [super init])) {
    return nil;
  }
    self.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
    _hasLiveMap = YES;
    _automaticallyReloadsMapImageOnOrientationChange = YES;
    _options = [[MKMapSnapshotOptions alloc] init];
    _options.region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);;

    _mapImage = [[ASImageNode alloc]init];
    _mapImage.clipsToBounds = YES;
    [self addSubnode:_mapImage];
    [self updateGesture];
    _maxSize = self.bounds.size;
    return self;
}

- (void)addAnnotations:(NSArray *)annotations
{
    ASDN::MutexLocker l(_propertyLock);
    if (annotations.count == 0) {
        return;
    }
    _annotations = [annotations copy];
    if (annotations.count != _annotations.count && _mapImage.image) {
        // Redraw
        [self setNeedsDisplay];
    }
}

- (void)setUpSnapshotter
{
    if (!_snapshotter) {
        _options.size = _nodeSize;
        _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
    }
}

- (BOOL)hasLiveMap
{
    ASDN::MutexLocker l(_propertyLock);
    return _hasLiveMap;
}

- (void)setHasLiveMap:(BOOL)hasLiveMap
{
    ASDN::MutexLocker l(_propertyLock);
    if (hasLiveMap == _hasLiveMap)
        return;
    
    _hasLiveMap = hasLiveMap;
    [self updateGesture];
}

- (CGSize)mapSize
{
    ASDN::MutexLocker l(_propertyLock);
    return _mapSize;
}

- (void)setMapSize:(CGSize)mapSize
{
    ASDN::MutexLocker l(_propertyLock);
    if (CGSizeEqualToSize(mapSize,_mapSize)) {
        return;
    }
    _mapSize = mapSize;
    _nodeSize = _mapSize;
    _automaticallyReloadsMapImageOnOrientationChange = NO;
    [self setNeedsLayout];
}

- (BOOL)automaticallyReloadsMapImageOnOrientationChange
{
    ASDN::MutexLocker l(_propertyLock);
    return _automaticallyReloadsMapImageOnOrientationChange;
}

- (void)setAutomaticallyReloadsMapImageOnOrientationChange:(BOOL)automaticallyReloadsMapImageOnOrientationChange
{
    ASDN::MutexLocker l(_propertyLock);
    if (_automaticallyReloadsMapImageOnOrientationChange == automaticallyReloadsMapImageOnOrientationChange) {
        return;
    }
    _automaticallyReloadsMapImageOnOrientationChange = automaticallyReloadsMapImageOnOrientationChange;
    
}

- (void)updateGesture
{
    _hasLiveMap ? [self addTarget:self action:@selector(showLiveMap) forControlEvents:ASControlNodeEventTouchUpInside] :  [self removeTarget:self action:@selector(showLiveMap) forControlEvents:ASControlNodeEventTouchUpInside];
}

- (void)fetchData
{
  [super fetchData];
    [self setUpSnapshotter];
    [self takeSnapshot];
}

- (void)clearFetchedData
{
    [super clearFetchedData];
    if (_liveMap) {
        [_liveMap removeFromSupernode];
        _liveMap = nil;
    }
    _mapImage.image = nil;
}

- (void)takeSnapshot
{
    if (!_snapshotter.isLoading) {
        [_snapshotter startWithCompletionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
            if (!error) {
                UIImage *image = snapshot.image;
                CGRect finalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
                
                // Get a standard annotation view pin. Future implementations should use a custom annotation image property.
                MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
                UIImage *pinImage = pin.image;
                
                UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
                [image drawAtPoint:CGPointMake(0, 0)];
                
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
                UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                _mapImage.image = finalImage;
            }
        }];
    }
}

- (void)resetSnapshotter
{
    if (!_snapshotter.isLoading) {
        _options.size = _nodeSize;
        _snapshotter = [[MKMapSnapshotter alloc] initWithOptions:_options];
    }
}

#pragma mark - Action
- (void)showLiveMap
{
    if (self.isNodeLoaded && !_liveMap) {
        _liveMap = [[ASDisplayNode alloc]initWithViewBlock:^UIView *{
            MKMapView *mapView = [[MKMapView alloc]initWithFrame:CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height)];
            mapView.delegate = _mapDelegate;
            [mapView setRegion:_options.region];
            [mapView addAnnotations:_annotations];
            return mapView;
        }];
        [self addSubnode:_liveMap];
        _mapImage.image = nil;
    }
}

#pragma mark - Layout
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
    _nodeSize = CGSizeEqualToSize(CGSizeZero, _mapSize) ? CGSizeMake(constrainedSize.width, _options.size.height) : _mapSize;
    if (_mapImage) {
        [_mapImage calculateSizeThatFits:_nodeSize];
    }
    return _nodeSize;
}

// Layout isn't usually needed in the box model, but since we are making use of MKMapView which is hidden in an ASDisplayNode this is preferred.
- (void)layout
{
    [super layout];
    if (_liveMap) {
        MKMapView *mapView = (MKMapView *)_liveMap.view;
        mapView.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height);
    }
    else {
        _mapImage.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, self.calculatedSize.height);
        if (!CGSizeEqualToSize(_maxSize, self.bounds.size)) {
            _mapImage.preferredFrameSize = self.bounds.size;
            _maxSize = self.bounds.size;
            if (_automaticallyReloadsMapImageOnOrientationChange && _mapImage.image) {
                [self resetSnapshotter];
                [self takeSnapshot];
            }
        }
    }
}

@end
