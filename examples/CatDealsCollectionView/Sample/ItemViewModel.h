//
//  GPDealViewModel.h
//  Groupon
//
//  Created by Samuel Stow on 12/29/15.
//  Copyright © 2015 Groupon Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ItemViewModel : NSObject

+ (instancetype)randomItem;

@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *firstInfoText;
@property (nonatomic, copy) NSString *secondInfoText;
@property (nonatomic, copy) NSString *originalPriceText;
@property (nonatomic, copy) NSString *finalPriceText;
@property (nonatomic, copy) NSString *soldOutText;
@property (nonatomic, copy) NSString *distanceLabelText;
@property (nonatomic, copy) NSString *badgeText;

- (NSURL *)imageURLWithSize:(CGSize)size;

@end
