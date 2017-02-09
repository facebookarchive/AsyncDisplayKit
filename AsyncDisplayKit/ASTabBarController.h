//
//  ASTabBarController.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 5/10/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASVisibilityProtocols.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ASTabBarController
 *
 * @discussion ASTabBarController is a drop in replacement for UITabBarController
 * which implements the memory efficiency improving @c ASManagesChildVisibilityDepth protocol.
 *
 * @see ASManagesChildVisibilityDepth
 */
@interface ASTabBarController : UITabBarController <ASManagesChildVisibilityDepth>

@end

NS_ASSUME_NONNULL_END
