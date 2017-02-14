//
//  UIResponder+AsyncDisplayKit.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/13/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIResponder (AsyncDisplayKit)

/**
 * The nearest view controller above this responder, if one exists.
 *
 * This property must be accessed on the main thread.
 */
@property (nonatomic, nullable, readonly) __kindof UIViewController *asdk_associatedViewController;

@end

NS_ASSUME_NONNULL_END
