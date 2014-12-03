/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASControlNode.h>

@protocol ASTextNodeDelegate;

/**
 * Highlight styles.
 */
typedef NS_ENUM(NSUInteger, ASTextNodeHighlightStyle) {
  /**
   * Highlight style for text on a light background.
   */
  ASTextNodeHighlightStyleLight,

  /**
   * Highlight style for text on a dark background.
   */
  ASTextNodeHighlightStyleDark
};

/**
 @abstract Draws interactive rich text.
 @discussion Backed by TextKit.
 */
@interface ASTextNode : ASControlNode

/**
 @abstract The attributed string to show.
 @discussion Defaults to nil, no text is shown.
 For inline image attachments, add an attribute of key NSAttachmentAttributeName, with a value of an NSTextAttachment.
 */
@property (nonatomic, copy) NSAttributedString *attributedString;

#pragma mark - Truncation

/**
 @abstract The attributedString to use when the text must be truncated.
 @discussion Defaults to a localized ellipsis character.
 */
@property (nonatomic, copy) NSAttributedString *truncationAttributedString;

/**
 @summary The second attributed string appended for truncation.
 @discussion This string will be highlighted on touches.
 @default nil
 */
@property (nonatomic, copy) NSAttributedString *additionalTruncationMessage;

/**
 @abstract Determines how the text is truncated to fit within the receiver's maximum size.
 @discussion Defaults to NSLineBreakByWordWrapping.
 */
@property (nonatomic, assign) NSLineBreakMode truncationMode;

/**
 @abstract If the text node is truncated. Text must have been sized first.
 */
@property (nonatomic, readonly, assign, getter=isTruncated) BOOL truncated;

/**
 @abstract The number of lines in the text. Text must have been sized first.
 */
@property (nonatomic, readonly, assign) NSUInteger lineCount;

#pragma mark - Placeholders

/**
 @abstract The placeholder color.
 */
@property (nonatomic, strong) UIColor *placeholderColor;

/**
 @abstract Inset each line of the placeholder.
 */
@property (nonatomic, assign) UIEdgeInsets placeholderInsets;

#pragma mark - Shadow

/**
 @abstract When you set these ASDisplayNode properties, they are composited into the bitmap instead of being applied by CA.

 @property (atomic, assign) CGColorRef shadowColor;
 @property (atomic, assign) CGFloat    shadowOpacity;
 @property (atomic, assign) CGSize     shadowOffset;
 @property (atomic, assign) CGFloat    shadowRadius;
 */

/**
 @abstract The number of pixels used for shadow padding on each side of the receiver.
 @discussion Each inset will be less than or equal to zero, so that applying
 UIEdgeInsetsRect(boundingRectForText, shadowPadding)
 will return a CGRect large enough to fit both the text and the appropriate shadow padding.
 */
@property (nonatomic, readonly, assign) UIEdgeInsets shadowPadding;

#pragma mark - Positioning

/**
 @abstract Returns an array of rects bounding the characters in a given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion Use this method to detect all the different rectangles a given range of text occupies.
 The rects returned are not guaranteed to be contiguous (for example, if the given text range spans
 a line break, the rects returned will be on opposite sides and different lines). The rects returned
 are in the coordinate system of the receiver.
 */
- (NSArray *)rectsForTextRange:(NSRange)textRange;

/**
 @abstract Returns an array of rects used for highlighting the characters in a given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion Use this method to detect all the different rectangles the highlights of a given range of text occupies.
 The rects returned are not guaranteed to be contiguous (for example, if the given text range spans
 a line break, the rects returned will be on opposite sides and different lines). The rects returned
 are in the coordinate system of the receiver. This method is useful for visual coordination with a
 highlighted range of text.
 */
- (NSArray *)highlightRectsForTextRange:(NSRange)textRange;

/**
 @abstract Returns a bounding rect for the given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion The height of the frame returned is that of the receiver's line-height; adjustment for
 cap-height and descenders is not performed. This method raises an exception if textRange is not
 a valid substring range of the receiver's string.
 */
- (CGRect)frameForTextRange:(NSRange)textRange;

/**
 @abstract Returns the trailing rectangle of space in the receiver, after the final character.
 @discussion Use this method to detect which portion of the receiver is not occupied by characters.
 The rect returned is in the coordinate system of the receiver.
 */
- (CGRect)trailingRect;


#pragma mark - Actions

/**
 @abstract The set of attribute names to consider links.  Defaults to NSLinkAttributeName.
 */
@property (nonatomic, copy) NSArray *linkAttributeNames;

/**
 @abstract Indicates whether the receiver has an entity at a given point.
 @param point The point, in the receiver's coordinate system.
 @param attributeNameOut The name of the attribute at the point. Can be NULL.
 @param rangeOut The ultimate range of the found text. Can be NULL.
 @result YES if an entity exists at `point`; NO otherwise.
 */
- (id)linkAttributeValueAtPoint:(CGPoint)point attributeName:(out NSString **)attributeNameOut range:(out NSRange *)rangeOut;

/**
 @abstract The style to use when highlighting text.
 */
@property (nonatomic, assign) ASTextNodeHighlightStyle highlightStyle;

/**
 @abstract The range of text highlighted by the receiver. Changes to this property are not animated by default.
 */
@property (nonatomic, assign) NSRange highlightRange;

/**
 @abstract Set the range of text to highlight, with optional animation.

 @param highlightRange The range of text to highlight.

 @param animated Whether the text should be highlighted with an animation.
 */
- (void)setHighlightRange:(NSRange)highlightRange animated:(BOOL)animated;

/**
 @abstract Responds to actions from links in the text node.
 */
@property (nonatomic, weak) id<ASTextNodeDelegate> delegate;

@end

/**
 * @abstract Text node delegate.
 */
@protocol ASTextNodeDelegate <NSObject>
@optional

/**
 @abstract Indicates to the delegate that a link was tapped within a text node.
 @param textNode The ASTextNode containing the link that was tapped.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was tapped.
 @param textRange The range of highlighted text.
 */
- (void)textNode:(ASTextNode *)textNode tappedLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point textRange:(NSRange)textRange;

/**
 @abstract Indicates to the delegate that a link was tapped within a text node.
 @param textNode The ASTextNode containing the link that was tapped.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was tapped.
 @param textRange The range of highlighted text.
 */
- (void)textNode:(ASTextNode *)textNode longPressedLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point textRange:(NSRange)textRange;

//! @abstract Called when the text node's truncation string has been tapped.
- (void)textNodeTappedTruncationToken:(ASTextNode *)textNode;

/**
 @abstract Indicates to the text node if an attribute should be considered a link.
 @param textNode The text node containing the entity attribute.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was touched to trigger a highlight.
 @discussion If not implemented, the default value is NO.
 @return YES if the entity attribute should be a link, NO otherwise.
 */
- (BOOL)textNode:(ASTextNode *)textNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point;

/**
 @abstract Indicates to the text node if an attribute is a valid long-press target
 @param textNode The text node containing the entity attribute.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was long-pressed.
 @discussion If not implemented, the default value is NO.
 @return YES if the entity attribute should be treated as a long-press target, NO otherwise.
 */
- (BOOL)textNode:(ASTextNode *)textNode shouldLongPressLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point;

@end
