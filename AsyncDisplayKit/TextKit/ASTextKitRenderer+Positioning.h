//
//  ASTextKitRenderer+Positioning.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTextKitRenderer.h>

typedef void (^as_text_component_index_block_t)(NSUInteger characterIndex,
                                                CGRect glyphBoundingRect,
                                                BOOL *stop);

/**
 Measure options are used to specify which type of line height measurement to use.

 ASTextNodeRendererMeasureOptionLineHeight is faster and will give the height from the baseline to the next line.

 ASTextNodeRendererMeasureOptionCapHeight is a more nuanced measure of the glyphs in the given range that attempts to
 produce a visually balanced rectangle above and below the glyphs to produce nice looking text highlights.

 ASTextNodeRendererMeasureOptionBlock uses the cap height option to generate each glyph index, but combines all but the
 first and last line rect into a single block.  Looks nice for multiline selection.
 */
typedef NS_ENUM(NSUInteger, ASTextKitRendererMeasureOption) {
  ASTextKitRendererMeasureOptionLineHeight,
  ASTextKitRendererMeasureOptionCapHeight,
  ASTextKitRendererMeasureOptionBlock
};

@interface ASTextKitRenderer (Positioning)

/**
 Returns the bounding rect for the given character range.

 @param textRange The character range for which the bounding rect will be computed.  Should be within the range of the
 attributedString of this renderer.

 @discussion In the external, shadowed coordinate space.
 */
- (CGRect)frameForTextRange:(NSRange)textRange;

/**
 Returns an array of rects representing the lines in the given character range

 @param textRange The character range for which the rects will be computed. Should be within the range of the
 attributedString of this renderer.
 @param measureOption The measure option to use for construction of the rects. See ASTextKitRendererMeasureOption
 docs for usage.

 @discussion This method is useful for providing highlighting text.  Returned rects are in the coordinate space of the
 renderer.

 Triggers initialization of textkit components, truncation, and sizing.
 */
- (NSArray *)rectsForTextRange:(NSRange)textRange
                 measureOption:(ASTextKitRendererMeasureOption)measureOption;

/**
 Enumerate the text character indexes at a position within the coordinate space of the renderer.

 @param position The point in the shadowed coordinate space at which text indexes will be enumerated.
 @param block The block that will be executed for each index identified that may correspond to the given position.  The
 block is given the character index that corresponds to the glyph at each index in question, as well as the bounding
 rect for that glyph.

 @discussion Glyph location based on a touch point is not an exact science because user touches are not well-represented
 by a simple point, especially in the context of link-heavy text.  So we have this method to make it a bit easier.  This
 method checks a grid of candidate positions around the touch point you give it, and computes the bounding rect of the
 glyph corresponding to the character index given.

 The bounding rect of the glyph can be used to identify the best glyph index that corresponds to your touch.  For
 instance, comparing centroidal distance from the glyph bounding rect to the touch center is useful for identifying
 which link a user actually intended to select.

 Triggers initialization of textkit components, truncation, and sizing.
 */
- (void)enumerateTextIndexesAtPosition:(CGPoint)position
                            usingBlock:(as_text_component_index_block_t)block;

/**
 Returns the single text index whose glyph's centroid is closest to the given position.

 @param position The point in the shadowed coordinate space that should be checked.

 @discussion This will use the grid enumeration function above, `enumerateTextIndexesAtPosition...`, in order to find
 the closest glyph, so it is possible that a glyph could be missed, but ultimately unlikely.
 */
- (NSUInteger)nearestTextIndexAtPosition:(CGPoint)position;

/**
 Returns the trailing rect unused by the renderer in the last rendered line.

 @discussion In the external shadowed coordinate space.

 Triggers initialization of textkit components, truncation, and sizing.
 */
- (CGRect)trailingRect;

@end
