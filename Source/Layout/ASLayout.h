//
//  ASLayout.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once
#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASLayoutElement.h>

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

extern CGPoint const CGPointNull;

extern BOOL CGPointIsNull(CGPoint point);

/**
 * Safely calculates the layout of the given root layoutElement by guarding against nil nodes.
 * @param rootLayoutElement The root node to calculate the layout for.
 * @param sizeRange The size range to calculate the root layout within.
 */
extern ASLayout *ASCalculateRootLayout(id<ASLayoutElement> rootLayoutElement, const ASSizeRange sizeRange);

/**
 * Safely computes the layout of the given node by guarding against nil nodes.
 * @param layoutElement The layout element to calculate the layout for.
 * @param sizeRange The size range to calculate the node layout within.
 * @param parentSize The parent size of the node to calculate the layout for.
 */
extern ASLayout *ASCalculateLayout(id<ASLayoutElement>layoutElement, const ASSizeRange sizeRange, const CGSize parentSize);

ASDISPLAYNODE_EXTERN_C_END

/**
 * A node in the layout tree that represents the size and position of the object that created it (ASLayoutElement).
 */
@interface ASLayout : NSObject

/**
 * The underlying object described by this layout
 */
@property (nonatomic, weak, readonly) id<ASLayoutElement> layoutElement;

/**
 * The type of ASLayoutElement that created this layout
 */
@property (nonatomic, assign, readonly) ASLayoutElementType type;

/**
 * Size of the current layout
 */
@property (nonatomic, assign, readonly) CGSize size;

/**
 * Position in parent. Default to CGPointNull.
 * 
 * @discussion When being used as a sublayout, this property must not equal CGPointNull.
 */
@property (nonatomic, assign, readonly) CGPoint position;

/**
 * Array of ASLayouts. Each must have a valid non-null position.
 */
@property (nonatomic, copy, readonly) NSArray<ASLayout *> *sublayouts;

/**
 * The frame for the given element, or CGRectNull if 
 * the element is not a direct descendent of this layout.
 */
- (CGRect)frameForElement:(id<ASLayoutElement>)layoutElement;

/**
 * @abstract Returns a valid frame for the current layout computed with the size and position.
 * @discussion Clamps the layout's origin or position to 0 if any of the calculated values are infinite.
 */
@property (nonatomic, assign, readonly) CGRect frame;

/**
 * Designated initializer
 */
- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                 size:(CGSize)size
                             position:(CGPoint)position
                           sublayouts:(nullable NSArray<ASLayout *> *)sublayouts NS_DESIGNATED_INITIALIZER;

/**
 * Convenience class initializer for layout construction.
 *
 * @param layoutElement The backing ASLayoutElement object.
 * @param size             The size of this layout.
 * @param position         The position of this layout within its parent (if available).
 * @param sublayouts       Sublayouts belong to the new layout.
 */
+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                               position:(CGPoint)position
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts AS_WARN_UNUSED_RESULT;

/**
 * Convenience initializer that has CGPointNull position.
 * Best used by ASDisplayNode subclasses that are manually creating a layout for -calculateLayoutThatFits:,
 * or for ASLayoutSpec subclasses that are referencing the "self" level in the layout tree,
 * or for creating a sublayout of which the position is yet to be determined.
 *
 * @param layoutElement  The backing ASLayoutElement object.
 * @param size              The size of this layout.
 * @param sublayouts        Sublayouts belong to the new layout.
 */
+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts AS_WARN_UNUSED_RESULT;

/**
 * Convenience that has CGPointNull position and no sublayouts.
 * Best used for creating a layout that has no sublayouts, and is either a root one
 * or a sublayout of which the position is yet to be determined.
 *
 * @param layoutElement The backing ASLayoutElement object.
 * @param size             The size of this layout.
 */
+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size AS_WARN_UNUSED_RESULT;
/**
 * Convenience initializer that creates a layout based on the values of the given layout, with a new position
 *
 * @param layout           The layout to use to create the new layout
 * @param position         The position of the new layout
 */
+ (instancetype)layoutWithLayout:(ASLayout *)layout position:(CGPoint)position AS_WARN_UNUSED_RESULT;

/**
 * Traverses the existing layout tree and generates a new tree that represents only ASDisplayNode layouts
 */
- (ASLayout *)filteredNodeLayoutTree AS_WARN_UNUSED_RESULT;

@end

@interface ASLayout (Unavailable)

- (instancetype)init __unavailable;

@end

#pragma mark - Deprecated

@interface ASLayout (Deprecated)

- (id <ASLayoutElement>)layoutableObject ASDISPLAYNODE_DEPRECATED;

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size ASDISPLAYNODE_DEPRECATED;

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size
                                sublayouts:(nullable NSArray<ASLayout *> *)sublayouts AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

@end

#pragma mark - Debugging

@interface ASLayout (Debugging)

/**
 * Recrusively output the description of the layout tree.
 */
- (NSString *)recursiveDescription;

@end

NS_ASSUME_NONNULL_END
