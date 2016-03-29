//
//  LocationCollectionViewController.h
//  Flickrgram
//
//  Created by Hannah Troisi on 2/24/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocation.h>

@interface LocationCollectionViewController : UICollectionViewController


- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
                             coordinates:(CLLocationCoordinate2D)coordiantes NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
