//
//  MTCustomMapAnnotation.h
//  ASDKMapTest
//
//  Created by Michal Ziman on 11/07/16.
//  Copyright © 2016 Michal Ziman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MTCustomMapAnnotation : NSObject<MKAnnotation>

@property (assign, nonatomic) CLLocationCoordinate2D coordinate;
@property (copy, nonatomic, nullable) UIImage *image;
@property (copy, nonatomic, nullable) NSString *title;
@property (copy, nonatomic, nullable) NSString *subtitle;

@end
