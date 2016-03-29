//
//  LocationModel.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/26/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreLocation/CoreLocation.h"

@interface LocationModel : NSObject

@property (nonatomic, assign, readonly) CLLocationCoordinate2D coordinates;
@property (nonatomic, strong, readonly) CLPlacemark            *placemark;
@property (nonatomic, strong, readonly) NSString               *locationString;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWith500pxPhoto:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (void)reverseGeocodedLocationWithCompletionBlock:(void (^)(LocationModel *))blockName;

@end
