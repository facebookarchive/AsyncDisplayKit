//
//  LocationModel.m
//  Sample
//
//  Created by Hannah Troisi on 2/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "LocationModel.h"
#import <CoreLocation/CLGeocoder.h>

@implementation LocationModel
{
  BOOL _placemarkFetchInProgress;
  void (^_placemarkCallbackBlock)(LocationModel *);
}

#pragma mark - Lifecycle

- (nullable instancetype)initWith500pxPhoto:(NSDictionary *)dictionary
{
  NSNumber *latitude  = [dictionary objectForKey:@"latitude"];
  NSNumber *longitude = [dictionary objectForKey:@"longitude"];
  
  // early return if location is "<null>"
  if (![latitude isKindOfClass:[NSNumber class]] || ![longitude isKindOfClass:[NSNumber class]]) {
    return nil;
  }
  
  self = [super init];
  
  if (self) {
    // set coordiantes
    _coordinates = CLLocationCoordinate2DMake([latitude floatValue], [longitude floatValue]);
    
    // get CLPlacemark with MKReverseGeocoder
    [self beginReverseGeocodingLocationFromCoordinates];
  }
  
  return self;
}

#pragma mark - Instance Methods

// return location placemark if fetched, else set completion block for fetch finish
- (void)reverseGeocodedLocationWithCompletionBlock:(void (^)(LocationModel *))blockName
{
  if (_placemark) {
    
    // call block if placemark already fetched
    if (blockName) {
      blockName(self);
    }

  } else {
    
    // set placemark reverse geocoding completion block
    _placemarkCallbackBlock = blockName;
    
    // if fetch not in progress, begin
    if (!_placemarkFetchInProgress) {
    
      [self beginReverseGeocodingLocationFromCoordinates];
    }
  }
}


#pragma mark - Helper Methods

- (void)beginReverseGeocodingLocationFromCoordinates
{
  if (_placemarkFetchInProgress) {
    return;
  }
  _placemarkFetchInProgress = YES;

  CLLocation *location = [[CLLocation alloc] initWithLatitude:_coordinates.latitude longitude:_coordinates.longitude];
  CLGeocoder *geocoder = [[CLGeocoder alloc] init];
  
  [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
    
    // completion handler gets called on main thread
    _placemark      = [placemarks lastObject];
    _locationString = [self locationStringFromCLPlacemark];
    
    // check if completion block set, call it - DO NOT CALL A NIL BLOCK!
    if (_placemarkCallbackBlock) {
      
      // call the block with arguments
      _placemarkCallbackBlock(self);
    }
  }];
}

- (nullable NSString *)locationStringFromCLPlacemark
{
  // early return if no location info
  if (!_placemark)
  {
    return nil;
  }
  
//  @property (nonatomic, readonly, copy, nullable) NSString *name; // eg. Apple Inc.
//  @property (nonatomic, readonly, copy, nullable) NSString *thoroughfare; // street name, eg. Infinite Loop
//  @property (nonatomic, readonly, copy, nullable) NSString *subThoroughfare; // eg. 1
//  @property (nonatomic, readonly, copy, nullable) NSString *locality; // city, eg. Cupertino
//  @property (nonatomic, readonly, copy, nullable) NSString *subLocality; // neighborhood, common name, eg. Mission District
//  @property (nonatomic, readonly, copy, nullable) NSString *administrativeArea; // state, eg. CA
//  @property (nonatomic, readonly, copy, nullable) NSString *subAdministrativeArea; // county, eg. Santa Clara
//  @property (nonatomic, readonly, copy, nullable) NSString *postalCode; // zip code, eg. 95014
//  @property (nonatomic, readonly, copy, nullable) NSString *ISOcountryCode; // eg. US
//  @property (nonatomic, readonly, copy, nullable) NSString *country; // eg. United States
//  @property (nonatomic, readonly, copy, nullable) NSString *inlandWater; // eg. Lake Tahoe
//  @property (nonatomic, readonly, copy, nullable) NSString *ocean; // eg. Pacific Ocean
//  @property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *areasOfInterest; // eg. Golden Gate Park
  
  NSString *locationString;
  
  if (_placemark.inlandWater) {
    locationString = _placemark.inlandWater;
  } else if (_placemark.subLocality && _placemark.locality) {
    locationString = [NSString stringWithFormat:@"%@, %@", _placemark.subLocality, _placemark.locality];
  } else if (_placemark.administrativeArea && _placemark.subAdministrativeArea) {
    locationString = [NSString stringWithFormat:@"%@, %@", _placemark.subAdministrativeArea, _placemark.administrativeArea];
  } else if (_placemark.country) {
    locationString = _placemark.country;
  } else {
    locationString = @"ERROR";
  }

  return locationString;
}

@end
