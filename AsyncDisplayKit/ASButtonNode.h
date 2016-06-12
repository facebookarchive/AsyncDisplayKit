//
//  ASButtonNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASImageNode.h>

@interface ASButtonNode : ASControlNode

@property (nonatomic, readonly) ASTextNode  * _Nonnull titleNode;
@property (nonatomic, readonly) ASImageNode * _Nonnull imageNode;
@property (nonatomic, readonly) ASImageNode * _Nonnull backgroundImageNode;

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
 *  Returns the styled title associated with the specified state.
 *
 *  @param state The state that uses the styled title. The possible values are described in ASControlState.
 *
 *  @return The title for the specified state.
 */
- (NSAttributedString * _Nullable)attributedTitleForState:(ASControlState)state;

/**
 *  Sets the styled title to use for the specified state. This will reset styled title previously set with -setTitle:withFont:withColor:forState.
 *
 *  @param title The styled text string to use for the title.
 *  @param state The state that uses the specified title. The possible values are described in ASControlState.
 */
- (void)setAttributedTitle:(nullable NSAttributedString *)title forState:(ASControlState)state;

#if TARGET_OS_IOS
/**
 *  Sets the title to use for the specified state. This will reset styled title previously set with -setAttributedTitle:forState.
 *
 *  @param title The styled text string to use for the title.
 *  @param font The font to use for the title.
 *  @param color The color to use for the title.
 *  @param state The state that uses the specified title. The possible values are described in ASControlState.
 */
- (void)setTitle:(nonnull NSString *)title withFont:(nullable UIFont *)font withColor:(nullable UIColor *)color forState:(ASControlState)state;
#endif
/**
 *  Returns the image used for a button state.
 *
 *  @param state The state that uses the image. Possible values are described in ASControlState.
 *
 *  @return The image used for the specified state.
 */
- (UIImage * _Nullable)imageForState:(ASControlState)state;

/**
 *  Sets the image to use for the specified state.
 *
 *  @param image The image to use for the specified state.
 *  @param state The state that uses the specified title. The values are described in ASControlState.
 */
- (void)setImage:(nullable UIImage *)image forState:(ASControlState)state;

/**
 *  Sets the background image to use for the specified state.
 *
 *  @param image The image to use for the specified state.
 *  @param state The state that uses the specified title. The values are described in ASControlState.
 */
- (void)setBackgroundImage:(nullable UIImage *)image forState:(ASControlState)state;


/**
 *  Returns the background image used for a button state.
 *
 *  @param state The state that uses the image. Possible values are described in ASControlState.
 *
 *  @return The background image used for the specified state.
 */
- (UIImage * _Nullable)backgroundImageForState:(ASControlState)state;

@end
