//
//  ASButtonNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ASImageNode, ASTextNode;

/**
 Image alignment defines where the image will be placed relative to the text.
 */
typedef NS_ENUM(NSInteger, ASButtonNodeImageAlignment) {
  /** Places the image before the text. */
  ASButtonNodeImageAlignmentBeginning,
  /** Places the image after the text. */
  ASButtonNodeImageAlignmentEnd
};

@interface ASButtonNode : ASControlNode

@property (nonatomic, readonly) ASTextNode  * titleNode;
@property (nonatomic, readonly) ASImageNode * imageNode;
@property (nonatomic, readonly) ASImageNode * backgroundImageNode;

/**
 Spacing between image and title. Defaults to 8.0.
 */
@property (nonatomic, assign) CGFloat contentSpacing;

/**
 Whether button should be laid out vertically (image on top of text) or horizontally (image to the left of text).
 ASButton node does not yet support RTL but it should be fairly easy to implement.
 Defaults to YES.
 */
@property (nonatomic, assign) BOOL laysOutHorizontally;

/** Horizontally align content (text or image).
 Defaults to ASHorizontalAlignmentMiddle.
 */
@property (nonatomic, assign) ASHorizontalAlignment contentHorizontalAlignment;

/** Vertically align content (text or image).
 Defaults to ASVerticalAlignmentCenter.
 */
@property (nonatomic, assign) ASVerticalAlignment contentVerticalAlignment;

/**
 * @discussion The insets used around the title and image node
 */
@property (nonatomic, assign) UIEdgeInsets contentEdgeInsets;

/**
 * @discusstion Whether the image should be aligned at the beginning or at the end of node. Default is `ASButtonNodeImageAlignmentBeginning`.
 */
@property (nonatomic, assign) ASButtonNodeImageAlignment imageAlignment;

/**
 *  Returns the styled title associated with the specified state.
 *
 *  @param state The control state that uses the styled title.
 *
 *  @return The title for the specified state.
 */
- (nullable NSAttributedString *)attributedTitleForState:(UIControlState)state AS_WARN_UNUSED_RESULT;

/**
 *  Sets the styled title to use for the specified state. This will reset styled title previously set with -setTitle:withFont:withColor:forState.
 *
 *  @param title The styled text string to use for the title.
 *  @param state The control state that uses the specified title.
 */
- (void)setAttributedTitle:(nullable NSAttributedString *)title forState:(UIControlState)state;

#if TARGET_OS_IOS
/**
 *  Sets the title to use for the specified state. This will reset styled title previously set with -setAttributedTitle:forState.
 *
 *  @param title The styled text string to use for the title.
 *  @param font The font to use for the title.
 *  @param color The color to use for the title.
 *  @param state The control state that uses the specified title.
 */
- (void)setTitle:(NSString *)title withFont:(nullable UIFont *)font withColor:(nullable UIColor *)color forState:(UIControlState)state;
#endif
/**
 *  Returns the image used for a button state.
 *
 *  @param state The control state that uses the image.
 *
 *  @return The image used for the specified state.
 */
- (nullable UIImage *)imageForState:(UIControlState)state AS_WARN_UNUSED_RESULT;

/**
 *  Sets the image to use for the specified state.
 *
 *  @param image The image to use for the specified state.
 *  @param state The control state that uses the specified title.
 */
- (void)setImage:(nullable UIImage *)image forState:(UIControlState)state;

/**
 *  Sets the background image to use for the specified state.
 *
 *  @param image The image to use for the specified state.
 *  @param state The control state that uses the specified title.
 */
- (void)setBackgroundImage:(nullable UIImage *)image forState:(UIControlState)state;


/**
 *  Returns the background image used for a button state.
 *
 *  @param state The control state that uses the image.
 *
 *  @return The background image used for the specified state.
 */
- (nullable UIImage *)backgroundImageForState:(UIControlState)state AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
