//
//  ASMainQueueTransaction.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/26/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASMainQueueTransaction : NSObject

+ (void)transactWithBlock:(void(^)())body;

+ (void)performOnMainThread:(void(^)())mainThreadWork;

@end

NS_ASSUME_NONNULL_END
