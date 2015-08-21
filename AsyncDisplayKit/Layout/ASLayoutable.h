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

@end
