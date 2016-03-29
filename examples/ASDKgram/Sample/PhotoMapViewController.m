//
//  PhotoMapViewController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 3/2/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoMapViewController.h"
#import <MapKit/MKMapView.h>
#import <MapKit/MKPointAnnotation.h>
#import <MapKit/MKUserLocation.h>

@interface PhotoMapViewController () <MKMapViewDelegate, CLLocationManagerDelegate>
@end

@implementation PhotoMapViewController
{
  MKMapView         *_mapView;
  UIButton          *_mapCrosshairsBtn;
  CLLocationManager *_locationManager;
  BOOL              _userLocationEnabled;
  BOOL              _CLLocationAuthorizationStatusDeniedAlertPresentedOnce;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  
  if (self) {
    
    self.navigationItem.title = @"Discover Nearby Photos";
    
    // location manager
    _locationManager          = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    // map view
    _mapView                  = [[MKMapView alloc] init];
    _mapView.delegate         = self;
    
    [self.view addSubview:_mapView];
    
    // map view - crosshairs button
    _mapCrosshairsBtn         = [UIButton buttonWithType:UIButtonTypeSystem];
    [_mapCrosshairsBtn setImage:[UIImage imageNamed:@"crosshairs"] forState:UIControlStateNormal];
    [_mapCrosshairsBtn addTarget:self action:@selector(centerMapOnUsersLocationIfLocationEnabled) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:_mapCrosshairsBtn];
    
    // check App's CLLocation authorization status
    [self checkCLAuthorizationStatusWithAlertForStatusDenied:NO];
  }
  
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  // check App's CLLocation authorization status & prompt user to enable if not authorized
  [self checkCLAuthorizationStatusWithAlertForStatusDenied:YES];
  
  if (_userLocationEnabled) {
    
    // if the user's location is enabled show it on the map
    _mapView.showsUserLocation = YES;
    
    [_locationManager startUpdatingLocation];
    
    // check if user's Location is in mapView visible area, if not center the map on the user
    MKMapPoint userPoint = MKMapPointForCoordinate(_mapView.userLocation.location.coordinate);
    MKMapRect mapRect    = _mapView.visibleMapRect;
    BOOL inside          = MKMapRectContainsPoint(mapRect, userPoint);
    if (!inside) {
      [self centerMapOnUsersLocation];
    }
  }
}

#define MAP_CROSSHAIRS_BTN_WIDTH 30
#define MAP_CROSSHAIRS_BTN_INSET 20
- (void)viewWillLayoutSubviews
{
  // FIXME: tune into NSNotification
  
  [super viewWillLayoutSubviews];
  
  CGSize boundsSize       = self.view.bounds.size;
  
  // layout map crosshairs button
  CGSize btnSize          = CGSizeMake(MAP_CROSSHAIRS_BTN_WIDTH, MAP_CROSSHAIRS_BTN_WIDTH);
  CGFloat x               = boundsSize.width - btnSize.width - MAP_CROSSHAIRS_BTN_INSET;
  CGFloat y               = CGRectGetMinY(self.tabBarController.tabBar.frame) - btnSize.width - MAP_CROSSHAIRS_BTN_INSET;
  _mapCrosshairsBtn.frame = (CGRect) {CGPointMake(x, y), btnSize};
  
  // layout mapView
  _mapView.frame          = self.view.bounds;
}

- (void)viewDidDisappear:(BOOL)animated
{
  if (_userLocationEnabled) {
    [_locationManager stopUpdatingLocation];
  }
}


#pragma mark - Helper Functions

- (void)centerMapOnUsersLocationIfLocationEnabled
{
  if (_userLocationEnabled) {
    [self centerMapOnUsersLocation];
  } else {
    [self checkCLAuthorizationStatusWithAlertForStatusDenied:YES];
  }
}

#define ZOOM_SPAN_DELTA 0.03
- (void)centerMapOnUsersLocation
{
  // set mapView region
  CLLocationCoordinate2D location;
  CLLocation *usersLocation = [_locationManager location];
  location.latitude         = usersLocation.coordinate.latitude;
  location.longitude        = usersLocation.coordinate.longitude;
  MKCoordinateSpan span     = MKCoordinateSpanMake(ZOOM_SPAN_DELTA, ZOOM_SPAN_DELTA);
  MKCoordinateRegion region = MKCoordinateRegionMake(location, span);
  
  [_mapView setRegion:region animated:YES];
}

- (void)checkCLAuthorizationStatusWithAlertForStatusDenied:(BOOL)showDeniedAlert
{
  // check app's permission to use location services
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  
  if (status == kCLAuthorizationStatusNotDetermined) {
    
    NSLog(@"App's permission to use location NOT DETERMINED");
    _userLocationEnabled = NO;
    [_locationManager requestWhenInUseAuthorization];
    
  } else if (status == kCLAuthorizationStatusDenied) {
    
    NSLog(@"App's permission to use location DENIED");
    
    _userLocationEnabled = NO;
    
    if (showDeniedAlert) {
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                               message:@"Location services disabled. See Settings > Flickergram > Location to change."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      
      UIAlertAction *acknowledgeAction = [UIAlertAction actionWithTitle:@"Ok"
                                                                  style:UIAlertActionStyleCancel
                                                                handler:^(UIAlertAction * _Nonnull action) {}];
      
      [alertController addAction:acknowledgeAction];
      
      [self presentViewController:alertController animated:YES completion:^{}];
    }
  
  } else if (status == kCLAuthorizationStatusRestricted) {
    
    NSLog(@"App's permission to use location RESTRICTED");
    _userLocationEnabled = NO;

  } else {
    
    NSLog(@"App has permission to use location");
    _userLocationEnabled = YES;
    _mapView.showsUserLocation = YES;
  }
}

#pragma mark - MKMapKitDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
  // FIXME:
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
  [self checkCLAuthorizationStatusWithAlertForStatusDenied:NO];
  [self centerMapOnUsersLocationIfLocationEnabled];
}

@end
