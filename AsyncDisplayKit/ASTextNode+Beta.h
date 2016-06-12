//
//  ASTextNode+Beta.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/25/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

NS_ASSUME_NONNULL_BEGIN

@interface ASTextNode ()

/**
 @abstract An array of descending scale factors that will be applied to this text node to try to make it fit within its constrained size
 @default nil (no scaling)
 */
@property (nullable, nonatomic, copy) NSArray *pointSizeScaleFactors;

#pragma mark - ASTextKit Customization
/**
 A block to provide a hook to provide a custom NSLayoutManager to the ASTextKitRenderer
 */
@property (nullable, nonatomic, copy) NSLayoutManager * (^layoutManagerCreationBlock)(void);

/**
 A block to provide a hook to provide a NSTextStorage to the TextKit's layout manager.
 */
@property (nullable, nonatomic, copy) NSTextStorage * (^textStorageCreationBlock)(NSAttributedString *_Nullable attributedString);

@end

NS_ASSUME_NONNULL_END
