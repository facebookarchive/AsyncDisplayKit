//
//  ItemViewModel.h
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 12/29/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
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
