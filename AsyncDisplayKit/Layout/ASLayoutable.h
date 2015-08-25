/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASStackLayoutDefines.h>

@class ASLayout;
@class ASLayoutSpec;

/** 
 * The ASLayoutable protocol declares a method for measuring the layout of an object. A class must implement the method
 * so that instances of that class can be used to build layout trees. The protocol also provides information 
 * about how an object should be laid out within an ASStackLayoutSpec.
 */
@protocol ASLayoutable <NSObject>

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize;

/**
 @abstract Give this object a last chance to add itself to a container ASLayoutable (most likely an ASLayoutSpec) before
 being added to a ASLayoutSpec.
 
 For example, consider a node whose superclass is laid out via calculateLayoutThatFits:. The subclass cannot implement
 layoutSpecThatFits: since its ASLayout is already being created by calculateLayoutThatFits:. By implementing this method
 a subclass can wrap itself in an ASLayoutSpec right before it is added to a layout spec.
 
 It is rare that a class will need to implement this method.
 */
- (id<ASLayoutable>)finalLayoutable;

@end
