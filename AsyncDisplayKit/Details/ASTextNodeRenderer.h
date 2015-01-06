/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

typedef void (^as_renderer_index_block_t)(NSUInteger characterIndex,
                                          CGRect glyphBoundingRect,
                                          BOOL *stop);

/*
 * Measure options are used to specify which type of line height measurement to
 * use.
 *
 * ASTextNodeRendererMeasureOptionLineHeight is faster and will give the
 * height from the baseline to the next line.
 *
 * ASTextNodeRendererMeasureOptionCapHeight is a more nuanced measure of the
 * glyphs in the given range that attempts to produce a visually balanced
 * rectangle above and below the glyphs to produce nice looking text highlights.
 *
 * ASTextNodeRendererMeasureOptionBlock uses the cap height option to
 * generate each glyph index, but combines all but the first and last line rect
 * into a single block.  Looks nice for multiline selection.
 *
 */
typedef NS_ENUM(NSUInteger, ASTextNodeRendererMeasureOption) {
  ASTextNodeRendererMeasureOptionLineHeight,
  ASTextNodeRendererMeasureOptionCapHeight,
  ASTextNodeRendererMeasureOptionBlock
};

/*
 * This is an immutable textkit renderer that is responsible for sizing and
 * rendering text.
 *
 * @discussion This class implements internal locking to allow it to be used
 * safely from background threads. It is recommended that you create and cache a
 * renderer for each combination of parameters.
 */
@interface ASTextNodeRenderer : NSObject

/*
 * Designated Initializer
 *
 * @discussion No sizing occurs as a result of initializing a renderer.
 * Instead, sizing and truncation operations occur lazily as they are needed,
 * so feel free
 */
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                        truncationString:(NSAttributedString *)truncationString
                          truncationMode:(NSLineBreakMode)truncationMode
                         constrainedSize:(CGSize)constrainedSize;
#pragma mark - Drawing
/*
 * Draw the renderer's text content into the bounds provided.
 *
 * @param bounds The rect in which to draw the contents of the renderer.
 * @param context The CGContext in which to draw the contents of the renderer.
 *
 * @discussion Note that if a shadow is to be drawn, then the text will actually
 * draw inside a region that is inset from the bounds provided.  Use
 * shadowPadding to properly transform the bounds such that this is correct for
 * your use-case.  See shadowPadding docs for more.
 *
 * Initializes the textkit components lazily if they have not yet been created.
 * You may want to consider triggering this cost before hitting the draw method
 * if you are sensitive to this cost in drawInRect...
 */
- (void)drawInRect:(CGRect)bounds inContext:(CGContextRef)context;

#pragma mark - Layout

/*
 * Returns the computed size of the renderer given the constrained size and
 * other parameters in the initializer.
 *
 * @discussion No actual computation is done in this method.  It simply returns
 * the cached calculated size from initialization so this is very cheap to call.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (CGSize)size;

/*
 * Returns the trailing rect unused by the renderer in the last rendered line.
 *
 * @discussion In the coordinate space of the renderer.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (CGRect)trailingRect;

/*
 * Returns the bounding rect for the given character range.
 *
 * @param textRange The character range for which the bounding rect will be
 * computed.  Should be within the range of the attributedString of this
 * renderer.
 *
 * @discussion In the coordinate space of the renderer.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (CGRect)frameForTextRange:(NSRange)textRange;

/*
 * Returns an array of rects representing the lines in the given character range
 *
 * @param textRange The character range for which the rects will be computed.
 * should be within the range of the attributedString of this renderer.
 * @param measureOption The measure option to use for construction of the rects.
 * see ASTextNodeRendererMeasureOption docs for usage.
 *
 * @discussion This method is useful for providing highlighting text.  Returned
 * rects are in the coordinate space of the renderer.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (NSArray *)rectsForTextRange:(NSRange)textRange
                 measureOption:(ASTextNodeRendererMeasureOption)measureOption;

/*
 * Enumerate the text character indexes at a position within the coordinate
 * space of the renderer.
 *
 * @param position The point inside the coordinate space of the renderer at
 * which text indexes will be enumerated.
 * @param block The block that will be executed for each index identified that
 * may correspond to the given position.  The block is given the character index
 * that corresponds to the glyph at each index in question, as well as the
 * bounding rect for that glyph.
 *
 * @discussion Glyph location based on a touch point is not an exact science
 * because user touches are not well-represented by a simple point, especially
 * in the context of link-heavy text.  So we have this method to make it a bit
 * easier.  This method checks a grid of candidate positions around the touch
 * point you give it, and computes the bounding rect of the glyph corresponding
 * to the character index given.
 *
 * The bounding rect of the glyph can be used to identify the best glyph index
 * that corresponds to your touch.  For instance, comparing centroidal distance
 * from the glyph bounding rect to the touch center is useful for identifying
 * which link a user actually intended to select.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (void)enumerateTextIndexesAtPosition:(CGPoint)position
                            usingBlock:(as_renderer_index_block_t)block;

#pragma mark - Text Ranges

/*
 * The character range that represents the truncationString provided in the
 * initializer.  location will be NSNotFound if no truncation occurred.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (NSRange)truncationStringCharacterRange;

/*
 * The character range from the original attributedString that is displayed by
 * the renderer given the parameters in the initializer.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (NSRange)visibleRange;

/*
 * The number of lines shown in the string.
 *
 * Triggers initialization of textkit components, truncation, and sizing.
 */
- (NSUInteger)lineCount;

@end
