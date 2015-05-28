/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutNode.h>

/**
 A layout node that wraps another node, applying insets around it.

 If the child node has a size specified as a percentage, the percentage is resolved against this node's parent
 size **after** applying insets.

 @example ASOuterLayoutNode contains an ASInsetLayoutNode with an ASInnerLayoutNode. Suppose that:
 - ASOuterLayoutNode is 200pt wide.
 - ASInnerLayoutNode specifies its width as 100%.
 - The ASInsetLayoutNode has insets of 10pt on every side.
 ASInnerLayoutNode will have size 180pt, not 200pt, because it receives a parent size that has been adjusted for insets.

 If you're familiar with CSS: ASInsetLayoutNode's child behaves similarly to "box-sizing: border-box".

 An infinite inset is resolved as an inset equal to all remaining space after applying the other insets and child size.
 @example An ASInsetLayoutNode with an infinite left inset and 10px for all other edges will position it's child 10px from the right edge.
 */
@interface ASInsetLayoutNode : ASLayoutNode

/**
 @param insets The amount of space to inset on each side.
 @param node The wrapped child layout node to inset. If nil, this method returns nil.
 */
+ (instancetype)newWithInsets:(UIEdgeInsets)insets
                         node:(ASLayoutNode *)node;

@end
