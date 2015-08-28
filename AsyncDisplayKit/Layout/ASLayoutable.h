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
#import <AsyncDisplayKit/ASRelativeSize.h>
#import <AsyncDisplayKit/ASStackLayoutDefines.h>

#import <AsyncDisplayKit/ASLayoutablePrivate.h>

@class ASLayout;
@class ASLayoutSpec;

/** 
 * The ASLayoutable protocol declares a method for measuring the layout of an object. A class must implement the method
 * so that instances of that class can be used to build layout trees. The protocol also provides information 
 * about how an object should be laid out within an ASStackLayoutSpec.
 */
@protocol ASLayoutable <ASLayoutablePrivate>

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize;

@property (nonatomic, readwrite) CGFloat spacingBefore;
@property (nonatomic, readwrite) CGFloat spacingAfter;
@property (nonatomic, readwrite) BOOL flexGrow;
@property (nonatomic, readwrite) BOOL flexShrink;
@property (nonatomic, readwrite) ASRelativeDimension flexBasis;
@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;

@property (nonatomic, readwrite) CGFloat ascender;
@property (nonatomic, readwrite) CGFloat descender;

@property (nonatomic, readwrite) ASRelativeSizeRange sizeRange;
@property (nonatomic, readwrite) CGPoint layoutPosition;

@end
