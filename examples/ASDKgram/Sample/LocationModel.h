//
//  LocationModel.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 2/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "CoreLocation/CoreLocation.h"

@interface LocationModel : NSObject

@property (nonatomic, assign, readonly) CLLocationCoordinate2D coordinates;
@property (nonatomic, strong, readonly) CLPlacemark            *placemark;
@property (nonatomic, strong, readonly) NSString               *locationString;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWith500pxPhoto:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (void)reverseGeocodedLocationWithCompletionBlock:(void (^)(LocationModel *))blockName;

@end
