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
#import <AsyncDisplayKit/ASLayout.h>

@interface ASLayoutNode ()

/** A constant that indicates that the parent's size is not yet determined in a given dimension. */
extern CGFloat const kASLayoutNodeParentDimensionUndefined;

/** A constant that indicates that the parent's size is not yet determined in either dimension. */
extern CGSize const kASLayoutNodeParentSizeUndefined;

/**
 Call this on children layout nodes to compute their layouts within your implementation of -computeLayoutThatFits:.

 @warning You may not override this method. Override -computeLayoutThatFits: instead.

 @param constrainedSize Specifies a minimum and maximum size. The receiver must choose a size that is in this range.
 @param parentSize The parent layout node's size. If the parent layout node does not have a final size in a given dimension,
                   then it should be passed as kASLayoutNodeParentDimensionUndefined (for example, if the parent's width
                   depends on the child's size).

 @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
                         parentSize:(CGSize)parentSize;

/**
 Override this method to compute your node's layout.

 @discussion Why do you need to override -computeLayoutThatFits: instead of -layoutThatFits:parentSize:?
 The base implementation of -layoutThatFits:parentSize: does the following for you:
 1. First, it uses the parentSize parameter to resolve the node's size (the one passed into -initWithSize:).
 2. Then, it intersects the resolved size with the constrainedSize parameter. If the two don't intersect,
    constrainedSize wins. This allows a node to always override its childrens' sizes when computing its layout.
    (The analogy for UIView: you might return a certain size from -sizeThatFits:, but a parent view can always override
    that size and set your frame to any size.)

 @param constrainedSize A min and max size. This is computed as described in the description. The ASLayout you
                        return MUST have a size between these two sizes. This is enforced by assertion.
 */
- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 ASLayoutNode's implementation of -layoutThatFits:parentSize: calls this method to resolve the node's size
 against parentSize, intersect it with constrainedSize, and call -computeLayoutThatFits: with the result.

 In certain advanced cases, you may want to customize this logic. Overriding this method allows you to receive all
 three parameters and do the computation yourself.

 @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
                          restrictedToSize:(ASLayoutNodeSize)size
                      relativeToParentSize:(CGSize)parentSize;

@end
