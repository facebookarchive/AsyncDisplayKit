//
//  ASTextKitAttributes.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <UIKit/UIKit.h>
#import "ASEqualityHelpers.h"

@protocol ASTextKitTruncating;

extern NSString *const ASTextKitTruncationAttributeName;
/**
 Use ASTextKitEntityAttribute as the value of this attribute to embed a link or other interactable content inside the
 text.
 */
extern NSString *const ASTextKitEntityAttributeName;

/**
 All NSObject values in this struct should be copied when passed into the TextComponent.
 */
struct ASTextKitAttributes {
  /**
   The string to be drawn.  ASTextKit will not augment this string with default colors, etc. so this must be complete.
   */
  NSAttributedString *attributedString;
  /**
   The string to use as the truncation string, usually just "...".  If you have a range of text you would like to
   restrict highlighting to (for instance if you have "... Continue Reading", use the ASTextKitTruncationAttributeName
   to mark the specific range of the string that should be highlightable.
   */
  NSAttributedString *truncationAttributedString;
  /**
   This is the character set that ASTextKit should attempt to avoid leaving as a trailing character before your
   truncation token.  By default this set includes "\s\t\n\r.,!?:;" so you don't end up with ugly looking truncation
   text like "Hey, this is some fancy Truncation!\n\n...".  Instead it would be truncated as "Hey, this is some fancy
   truncation...".  This is not always possible.

   Set this to the empty charset if you want to just use the "dumb" truncation behavior.  A nil value will be
   substituted with the default described above.
   */
  NSCharacterSet *avoidTailTruncationSet;
  /**
   The line-break mode to apply to the text.  Since this also impacts how TextKit will attempt to truncate the text
   in your string, we only support NSLineBreakByWordWrapping and NSLineBreakByCharWrapping.
   */
  NSLineBreakMode lineBreakMode;
  /**
   The maximum number of lines to draw in the drawable region.  Leave blank or set to 0 to define no maximum.
   This is required to apply scale factors to shrink text to fit within a number of lines
   */
  NSUInteger maximumNumberOfLines;
  /**
   An array of UIBezierPath objects representing the exclusion paths inside the receiver's bounding rectangle. Default value: nil.
   */
  NSArray *exclusionPaths;
  /**
   The shadow offset for any shadows applied to the text.  The coordinate space for this is the same as UIKit, so a
   positive width means towards the right, and a positive height means towards the bottom.
   */
  CGSize shadowOffset;
  /**
   The color to use in drawing the text's shadow.
   */
  UIColor *shadowColor;
  /**
   The opacity of the shadow from 0 to 1.
   */
  CGFloat shadowOpacity;
  /**
   The radius that should be applied to the shadow blur.  Larger values mean a larger, more blurred shadow.
   */
  CGFloat shadowRadius;
  /**
   An array of scale factors in descending order to apply to the text to try to make it fit into a constrained size.
   */
  NSArray *pointSizeScaleFactors;
  /**
   An optional block that returns a custom layout manager subclass. If nil, defaults to NSLayoutManager.
   */
  NSLayoutManager * (^layoutManagerCreationBlock)(void);
  
  /**
   An optional delegate for the NSLayoutManager
   */
  id<NSLayoutManagerDelegate> layoutManagerDelegate;

  /**
   An optional block that returns a custom NSTextStorage for the layout manager. 
   */
  NSTextStorage * (^textStorageCreationBlock)(NSAttributedString *attributedString);

  /**
   We provide an explicit copy function so we can use aggregate initializer syntax while providing copy semantics for
   the NSObjects inside.
   */
  const ASTextKitAttributes copy() const
  {
    return {
      [attributedString copy],
      [truncationAttributedString copy],
      [avoidTailTruncationSet copy],
      lineBreakMode,
      maximumNumberOfLines,
      [exclusionPaths copy],
      shadowOffset,
      [shadowColor copy],
      shadowOpacity,
      shadowRadius,
      pointSizeScaleFactors,
      layoutManagerCreationBlock,
      layoutManagerDelegate,
      textStorageCreationBlock,
    };
  };

  bool operator==(const ASTextKitAttributes &other) const
  {
    // These comparisons are in a specific order to reduce the overall cost of this function.
    return lineBreakMode == other.lineBreakMode
    && maximumNumberOfLines == other.maximumNumberOfLines
    && shadowOpacity == other.shadowOpacity
    && shadowRadius == other.shadowRadius
    && [pointSizeScaleFactors isEqualToArray:other.pointSizeScaleFactors]
    && layoutManagerCreationBlock == other.layoutManagerCreationBlock
    && textStorageCreationBlock == other.textStorageCreationBlock
    && CGSizeEqualToSize(shadowOffset, other.shadowOffset)
    && ASObjectIsEqual(exclusionPaths, other.exclusionPaths)
    && ASObjectIsEqual(avoidTailTruncationSet, other.avoidTailTruncationSet)
    && ASObjectIsEqual(shadowColor, other.shadowColor)
    && ASObjectIsEqual(attributedString, other.attributedString)
    && ASObjectIsEqual(truncationAttributedString, other.truncationAttributedString);
  }

  size_t hash() const;
};
