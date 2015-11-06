//
//  TextStyles.h
//  Sample
//
//  Created by Vitaly Baev on 06.11.15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TextStyles : NSObject

+ (NSDictionary *)nameStyle;
+ (NSDictionary *)usernameStyle;
+ (NSDictionary *)timeStyle;
+ (NSDictionary *)postStyle;
+ (NSDictionary *)postLinkStyle;
+ (NSDictionary *)cellControlStyle;
+ (NSDictionary *)cellControlColoredStyle;

@end
