/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <objc/message.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ASBaseDefines.h"

ASDISPLAYNODE_INLINE CGFloat ceilPixelValueForScale(CGFloat f, CGFloat scale)
{
  // Round up to device pixel (.5 on retina)
  return ceilf(f * scale) / scale;
}

ASDISPLAYNODE_INLINE CGSize ceilSizeValue(CGSize s)
{
  CGFloat screenScale = [UIScreen mainScreen].scale;
  s.width = ceilPixelValueForScale(s.width, screenScale);
  s.height = ceilPixelValueForScale(s.height, screenScale);
  return s;
}

@interface ASTextKitComponents : NSObject

/**
 @abstract Creates the stack of TextKit components.
 @param attributedSeedString The attributed string to seed the returned text storage with, or nil to receive an blank text storage.
 @param textContainerSize The size of the text-container. Typically, size specifies the constraining width of the layout, and FLT_MAX for height. Pass CGSizeZero if these components will be hooked up to a UITextView, which will manage the text container's size itself.
 @return An `ASTextKitComponents` containing the created components. The text view component will be nil.
 @discussion The returned components will be hooked up together, so they are ready for use as a system upon return.
 */
+ (ASTextKitComponents *)componentsWithAttributedSeedString:(NSAttributedString *)attributedSeedString
                                          textContainerSize:(CGSize)textContainerSize;

/**
 @abstract Returns the bounding size for the text view's text.
 @param components The TextKit components to calculate the constrained size of the text for.
 @param constrainedWidth The constraining width to be used during text-sizing. Usually, this value should be the receiver's calculated size.
 @result A CGSize representing the bounding size for the receiver's text.
 */
- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth;

@property (nonatomic, strong, readonly) NSTextStorage *textStorage;
@property (nonatomic, strong, readonly) NSTextContainer *textContainer;
@property (nonatomic, strong, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, strong) UITextView *textView;

@end
