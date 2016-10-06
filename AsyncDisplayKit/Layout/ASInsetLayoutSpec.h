//
//  ASInsetLayoutSpec.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A layout spec that wraps another layoutElement child, applying insets around it.

 If the child has a size specified as a fraction, the fraction is resolved against this spec's parent
 size **after** applying insets.

 @example ASOuterLayoutSpec contains an ASInsetLayoutSpec with an ASInnerLayoutSpec. Suppose that:
 - ASOuterLayoutSpec is 200pt wide.
 - ASInnerLayoutSpec specifies its width as 100%.
 - The ASInsetLayoutSpec has insets of 10pt on every side.
 ASInnerLayoutSpec will have size 180pt, not 200pt, because it receives a parent size that has been adjusted for insets.

 If you're familiar with CSS: ASInsetLayoutSpec's child behaves similarly to "box-sizing: border-box".

 An infinite inset is resolved as an inset equal to all remaining space after applying the other insets and child size.
 @example An ASInsetLayoutSpec with an infinite left inset and 10px for all other edges will position it's child 10px from the right edge.
 */
@interface ASInsetLayoutSpec : ASLayoutSpec

@property (nonatomic, assign) UIEdgeInsets insets;

/**
 @param insets The amount of space to inset on each side.
 @param child The wrapped child to inset.
 */
+ (instancetype)insetLayoutSpecWithInsets:(UIEdgeInsets)insets child:(id<ASLayoutElement>)child AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
