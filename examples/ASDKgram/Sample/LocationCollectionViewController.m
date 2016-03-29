//
//  LocationCollectionViewController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/24/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "LocationCollectionViewController.h"
#import "PhotoCollectionViewCell.h"
#import "PhotoFeedModel.h"
#import <MapKit/MKMapView.h>
#import <MapKit/MKPointAnnotation.h>


#define MAP_HEIGHT_VERTICAL_SCREEN_RATIO 0.3

@implementation LocationCollectionViewController
{
  CLLocationCoordinate2D  _coordinates;
  MKMapView              *_mapView;
  PhotoFeedModel         *_photoFeed;
}


#pragma mark - Lifecycle

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
                                 coordinates:(CLLocationCoordinate2D)coordiantes

{
  self = [super initWithCollectionViewLayout:layout];

  if (self) {
        
    CGRect screenRect   = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize imageSize    = CGSizeMake(screenRect.size.width * screenScale / 3.0, screenRect.size.width * screenScale / 3.0);
    
    _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypeLocation imageSize:imageSize];
    [_photoFeed updatePhotoFeedModelTypeLocationCoordinates:coordiantes radiusInMiles:10];
    [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos) {
      [self.collectionView reloadData];
    } numResultsToReturn:21];
    
    // set collection view dataSource and delegate
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.allowsSelection = NO;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    // register cell class
    [self.collectionView registerClass:[PhotoCollectionViewCell class] forCellWithReuseIdentifier:@"photo"];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerView"];
    
    // configure MKMapView & add as subview
    _mapView = [[MKMapView alloc] init];
    _mapView.showsUserLocation = YES;
  
    // set coordinates
    _coordinates = coordiantes;
  
  }

  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  // add annotation for coordinates
  MKPointAnnotation *photoLocationAnnotation = [[MKPointAnnotation alloc] init];
  photoLocationAnnotation.coordinate = _coordinates;
  [_mapView addAnnotation:photoLocationAnnotation];
  
  // center map on photo pin
  [_mapView setCenterCoordinate:_coordinates];
  
  // set map span and region
  MKCoordinateSpan span = MKCoordinateSpanMake(5, 5);
  MKCoordinateRegion region = MKCoordinateRegionMake(_coordinates, span);
  [_mapView setRegion:region animated:NO];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_photoFeed numberOfItemsInFeed];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  // dequeue a reusable cell
  PhotoCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"photo" forIndexPath:indexPath];
  
  // configure the cell for the appropriate photo
  [cell updateCellWithPhotoObject:[_photoFeed objectAtIndex:indexPath.row]];
  
  return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *reusableview = nil;
  
  if (kind == UICollectionElementKindSectionHeader) {
    UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerView" forIndexPath:indexPath];
    
    if (!headerView) {
      headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerView" forIndexPath:indexPath];
    }
    
    _mapView.frame = headerView.frame;
    [headerView addSubview:_mapView];

    reusableview = headerView;
  }
  
  return reusableview;
}


@end
