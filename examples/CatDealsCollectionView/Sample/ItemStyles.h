//
//  ItemStyles.h
//  Sample
//
//  Created by Samuel Stow on 12/30/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ItemStyles : NSObject
+ (NSDictionary *)titleStyle;
+ (NSDictionary *)subtitleStyle;
+ (NSDictionary *)distanceStyle;
+ (NSDictionary *)secondInfoStyle;
+ (NSDictionary *)originalPriceStyle;
+ (NSDictionary *)finalPriceStyle;
+ (NSDictionary *)soldOutStyle;
+ (NSDictionary *)badgeStyle;
+ (UIColor *)badgeColor;
+ (UIImage *)placeholderImage;
@end
