//
//  ASDisplayNode+Convenience.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@class UIViewController;

@interface ASDisplayNode (Convenience)

/**
 * @abstract Returns the view controller nearest to this node in the view hierarchy.
 *
 * @warning This property may only be accessed on the main thread.
 */
@property (nonatomic, nullable, readonly) __kindof UIViewController *closestViewController;

@end

NS_ASSUME_NONNULL_END
