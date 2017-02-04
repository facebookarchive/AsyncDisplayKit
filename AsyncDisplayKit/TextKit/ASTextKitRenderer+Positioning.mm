//
//  ASTextKitRenderer+Positioning.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTextKitRenderer+Positioning.h>

#import <CoreText/CoreText.h>
#import <tgmath.h>

#import <AsyncDisplayKit/ASAssert.h>

#import <AsyncDisplayKit/ASTextKitContext.h>
#import <AsyncDisplayKit/ASTextKitShadower.h>

static const CGFloat ASTextKitRendererGlyphTouchHitSlop = 5.0;
static const CGFloat ASTextKitRendererTextCapHeightPadding = 1.3;

@implementation ASTextKitRenderer (Tracking)

- (NSArray *)rectsForTextRange:(NSRange)textRange measureOption:(ASTextKitRendererMeasureOption)measureOption
{
  __block NSArray *textRects = nil;
  [self.context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    textRects = [self unlockedRectsForTextRange:textRange measureOptions:measureOption layoutManager:layoutManager textStorage:textStorage textContainer:textContainer];
  }];
  return textRects;
}

/**
 Helper function that should be called within performBlockWithLockedTextKitComponents: in an already locked state to
 prevent a deadlock
 */
- (NSArray *)unlockedRectsForTextRange:(NSRange)textRange measureOptions:(ASTextKitRendererMeasureOption)measureOption layoutManager:(NSLayoutManager *)layoutManager textStorage:(NSTextStorage *)textStorage textContainer:(NSTextContainer *)textContainer
{
  NSRange clampedRange = NSIntersectionRange(textRange, NSMakeRange(0, [textStorage length]));
  if (clampedRange.location == NSNotFound || clampedRange.length == 0) {
    return @[];
  }

  // Used for block measure option
  __block CGRect firstRect = CGRectNull;
  __block CGRect lastRect = CGRectNull;
  __block CGRect blockRect = CGRectNull;
  NSMutableArray *mutableTextRects = [NSMutableArray array];

  NSString *string = textStorage.string;

  NSRange totalGlyphRange = [layoutManager glyphRangeForCharacterRange:clampedRange actualCharacterRange:NULL];

  [layoutManager enumerateLineFragmentsForGlyphRange:totalGlyphRange usingBlock:^(CGRect rect,
                                                                                  CGRect usedRect,
                                                                                  NSTextContainer *innerTextContainer,
                                                                                  NSRange glyphRange,
                                                                                  BOOL *stop) {

    CGRect lineRect = CGRectNull;
    // If we're empty, don't bother looping through glyphs, use the default.
    if (CGRectIsEmpty(usedRect)) {
      lineRect = usedRect;
    } else {
      // TextKit's bounding rect computations are just a touch off, so we actually
      // compose the rects by hand from the center of the given TextKit bounds and
      // imposing the font attributes returned by the glyph's font.
      NSRange lineGlyphRange = NSIntersectionRange(totalGlyphRange, glyphRange);
      for (NSUInteger i = lineGlyphRange.location; i < NSMaxRange(lineGlyphRange) && i < string.length; i++) {
        // We grab the properly sized rect for the glyph
        CGRect properGlyphRect = [self _internalRectForGlyphAtIndex:i
                                                      measureOption:measureOption
                                                      layoutManager:layoutManager
                                                      textContainer:textContainer
                                                        textStorage:textStorage];

        // Don't count empty glyphs towards our line rect.
        if (!CGRectIsEmpty(properGlyphRect)) {
          lineRect = CGRectIsNull(lineRect) ? properGlyphRect
          : CGRectUnion(lineRect, properGlyphRect);
        }
      }
    }

    if (!CGRectIsNull(lineRect)) {
      if (measureOption == ASTextKitRendererMeasureOptionBlock) {
        // For the block measurement option we store the first & last rect as
        // special cases, then merge everything else into a single block rect
        if (CGRectIsNull(firstRect)) {
          // We don't have a firstRect, so we must be on the first line.
          firstRect = lineRect;
        } else if(CGRectIsNull(lastRect)) {
          // We don't have a lastRect, but we do have a firstRect, so we must
          // be on the second line.  No need to merge in the blockRect just yet
          lastRect = lineRect;
        } else if(CGRectIsNull(blockRect)) {
          // We have both a first and last rect, so we must be on the third line
          // we don't have any blockRect to merge it into, so we just set it
          // directly.
          blockRect = lastRect;
          lastRect = lineRect;
        } else {
          // Everything is already set, so we just merge this line into the
          // block.
          blockRect = CGRectUnion(blockRect, lastRect);
          lastRect = lineRect;
        }
      } else {
        // If the block option isn't being used then each line is being treated
        // individually.
        [mutableTextRects addObject:[NSValue valueWithCGRect:[self.shadower offsetRectWithInternalRect:lineRect]]];
      }
    }
  }];

  if (measureOption == ASTextKitRendererMeasureOptionBlock) {
    // Block measure option is handled differently with just 3 vars for the entire range.
    if (!CGRectIsNull(firstRect)) {
      if (!CGRectIsNull(blockRect)) {
        CGFloat rightEdge = MAX(CGRectGetMaxX(blockRect), CGRectGetMaxX(lastRect));
        if (rightEdge > CGRectGetMaxX(firstRect)) {
          // Force the right side of the first rect to properly align with the
          // right side of the rightmost of the block and last rect
          firstRect.size.width += rightEdge - CGRectGetMaxX(firstRect);
        }

        // Force the left side of the block rect to properly align with the
        // left side of the leftmost of the first and last rect
        blockRect.origin.x = MIN(CGRectGetMinX(firstRect), CGRectGetMinX(lastRect));
        // Force the right side of the block rect to properly align with the
        // right side of the rightmost of the first and last rect
        blockRect.size.width += MAX(CGRectGetMaxX(firstRect), CGRectGetMaxX(lastRect)) - CGRectGetMaxX(blockRect);
      }
      if (!CGRectIsNull(lastRect)) {
        // Force the left edge of the last rect to properly align with the
        // left side of the leftmost of the first and block rect, if necessary.
        CGFloat leftEdge = MIN(CGRectGetMinX(blockRect), CGRectGetMinX(firstRect));
        CGFloat lastRectNudgeAmount = MAX(CGRectGetMinX(lastRect) - leftEdge, 0);
        lastRect.origin.x = MIN(leftEdge, CGRectGetMinX(lastRect));
        lastRect.size.width += lastRectNudgeAmount;
      }

      [mutableTextRects addObject:[NSValue valueWithCGRect:[self.shadower offsetRectWithInternalRect:firstRect]]];
    }
    if (!CGRectIsNull(blockRect)) {
      [mutableTextRects addObject:[NSValue valueWithCGRect:[self.shadower offsetRectWithInternalRect:blockRect]]];
    }
    if (!CGRectIsNull(lastRect)) {
      [mutableTextRects addObject:[NSValue valueWithCGRect:[self.shadower offsetRectWithInternalRect:lastRect]]];
    }
  }

  return [mutableTextRects copy];
}

- (NSUInteger)nearestTextIndexAtPosition:(CGPoint)position
{
  // Check in a 9-point region around the actual touch point so we make sure
  // we get the best attribute for the touch.
  __block CGFloat minimumGlyphDistance = CGFLOAT_MAX;
  __block NSUInteger minimumGlyphCharacterIndex = NSNotFound;

  [self enumerateTextIndexesAtPosition:position usingBlock:^(NSUInteger characterIndex, CGRect glyphBoundingRect, BOOL *stop) {
    CGPoint glyphLocation = CGPointMake(CGRectGetMidX(glyphBoundingRect), CGRectGetMidY(glyphBoundingRect));
    CGFloat currentDistance = std::sqrt(std::pow(position.x - glyphLocation.x, 2.f) + std::pow(position.y - glyphLocation.y, 2.f));
    if (currentDistance < minimumGlyphDistance) {
      minimumGlyphDistance = currentDistance;
      minimumGlyphCharacterIndex = characterIndex;
    }
  }];
  return minimumGlyphCharacterIndex;
}

/**
 Measured from the internal coordinate space of the context, not accounting for shadow offsets.  Actually uses CoreText
 as an approximation to work around problems in TextKit's glyph sizing.
 */
- (CGRect)_internalRectForGlyphAtIndex:(NSUInteger)glyphIndex
                         measureOption:(ASTextKitRendererMeasureOption)measureOption
                         layoutManager:(NSLayoutManager *)layoutManager
                         textContainer:(NSTextContainer *)textContainer
                           textStorage:(NSTextStorage *)textStorage
{
  NSUInteger charIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  CGGlyph glyph = [layoutManager glyphAtIndex:glyphIndex];
  CTFontRef font = (__bridge_retained CTFontRef)[textStorage attribute:NSFontAttributeName
                                                               atIndex:charIndex
                                                        effectiveRange:NULL];
  if (font == nil) {
    font = (__bridge_retained CTFontRef)[UIFont systemFontOfSize:12.0];
  }

  //                                    Glyph Advance
  //                             +-------------------------+
  //                             |                         |
  //                             |                         |
  // +------------------------+--|-------------------------|--+-----------+-----+ What TextKit returns sometimes
  // |                        |  |             XXXXXXXXXXX +  |           |     | (approx. correct height, but
  // |               ---------|--+---------+  XXX       XXXX +|-----------|-----|  sometimes inaccurate bounding
  // |               |        |             XXX          XXXXX|           |     |  widths)
  // |               |        |             XX             XX |           |     |
  // |               |        |            XX                 |           |     |
  // |               |        |           XXX                 |           |     |
  // |               |        |           XX                  |           |     |
  // |               |        |      XXXXXXXXXXX              |           |     |
  // |   Cap Height->|        |          XX                   |           |     |
  // |               |        |          XX                   |  Ascent-->|     |
  // |               |        |          XX                   |           |     |
  // |               |        |          XX                   |           |     |
  // |               |        |          X                    |           |     |
  // |               |        |          X                    |           |     |
  // |               |        |          X                    |           |     |
  // |               |        |         XX                    |           |     |
  // |               |        |         X                     |           |     |
  // |               ---------|-------+ X +-------------------------------------|
  // |                        |        XX                     |                 |
  // |                        |        X                      |                 |
  // |                        |      XX         Descent------>|                 |
  // |                        | XXXXXX                        |                 |
  // |                        |  XXX                          |                 |
  // +------------------------+-------------------------------------------------+
  //                                                          |
  //                                                          +--+Actual bounding box

  CGRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                           inTextContainer:textContainer];

  // If it is a NSTextAttachment, we don't have the matched glyph and use width of glyphRect instead of advance.
  CGFloat advance = (glyph == kCGFontIndexInvalid) ? glyphRect.size.width : CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, NULL, 1);

  // We treat the center of the glyph's bounding box as the center of our new rect
  CGPoint glyphCenter = CGPointMake(CGRectGetMidX(glyphRect), CGRectGetMidY(glyphRect));

  CGRect properGlyphRect;
  if (measureOption == ASTextKitRendererMeasureOptionCapHeight
      || measureOption == ASTextKitRendererMeasureOptionBlock) {
    CGFloat ascent = CTFontGetAscent(font);
    CGFloat descent = CTFontGetDescent(font);
    CGFloat capHeight = CTFontGetCapHeight(font);
    CGFloat leading = CTFontGetLeading(font);
    CGFloat glyphHeight = ascent + descent;

    // For visual balance, we add the cap height padding above the cap, and
    // below the baseline, we scale by the descent so it grows with the size of
    // the text.
    CGFloat topPadding = ASTextKitRendererTextCapHeightPadding * descent;
    CGFloat bottomPadding = topPadding;

    properGlyphRect = CGRectMake(glyphCenter.x - advance * 0.5,
                                 glyphCenter.y - glyphHeight * 0.5 + (ascent - capHeight) - topPadding + leading,
                                 advance,
                                 capHeight + topPadding + bottomPadding);
  } else {
    // We are just measuring the line heights here, so we can use the
    // heights used by TextKit, which tend to be pretty good.
    properGlyphRect = CGRectMake(glyphCenter.x - advance * 0.5,
                                 glyphRect.origin.y,
                                 advance,
                                 glyphRect.size.height);
  }

  CFRelease(font);

  return properGlyphRect;
}

- (void)enumerateTextIndexesAtPosition:(CGPoint)externalPosition usingBlock:(as_text_component_index_block_t)block
{
  // This method is a little complex because it has to call out to client code from inside an enumeration that needs
  // to achieve a lock on the textkit components.  It cannot call out to client code from within that lock so we just
  // perform the textkit-locked ops inside the locked context.
  ASTextKitContext *lockingContext = self.context;
  CGPoint internalPosition = [self.shadower offsetPointWithExternalPoint:externalPosition];
  __block BOOL invalidPosition = NO;
  [lockingContext performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    invalidPosition = internalPosition.x > textContainer.size.width
    || internalPosition.y > textContainer.size.height
    || block == NULL;
  }];
  if (invalidPosition) {
    // Short circuit if the position is outside the size of this renderer, or if the block is null.
    return;
  }

  // We break it up into a 44pt box for the touch, and find the closest link attribute-containing glyph to the center of
  // the touch.
  CGFloat squareSide = 44.f;
  // Should be odd if you want to test the center of the touch.
  NSInteger pointsOnASide = 3;

  // The distance between any 2 of the adjacent points
  CGFloat pointSeparation = squareSide / pointsOnASide;
  // These are for tracking which point we're on.  We start with -pointsOnASide/2 and go to pointsOnASide/2.  So if
  // pointsOnASide=3, we go from -1 to 1.
  NSInteger endIndex = pointsOnASide / 2;
  NSInteger startIndex = -endIndex;

  BOOL stop = NO;
  for (NSInteger i = startIndex; i <= endIndex && !stop; i++) {
    for (NSInteger j = startIndex; j <= endIndex && !stop; j++) {
      CGPoint currentPoint = CGPointMake(internalPosition.x + i * pointSeparation,
                                         internalPosition.y + j * pointSeparation);

      __block NSUInteger characterIndex = NSNotFound;
      __block BOOL isValidGlyph = NO;
      __block CGRect glyphRect = CGRectNull;

      [lockingContext performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
        // We ask the layout manager for the proper glyph at the touch point
        NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:currentPoint
                                                  inTextContainer:textContainer];

        // If it's an invalid glyph, quit.

        [layoutManager glyphAtIndex:glyphIndex isValidIndex:&isValidGlyph];
        if (!isValidGlyph) {
          return;
        }

        characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];

        glyphRect = [self _internalRectForGlyphAtIndex:glyphIndex
                                         measureOption:ASTextKitRendererMeasureOptionLineHeight
                                         layoutManager:layoutManager
                                         textContainer:textContainer
                                           textStorage:textStorage];
      }];

      // Sometimes TextKit plays jokes on us and returns glyphs that really aren't close to the point in question.
      // Silly TextKit...
      if (!isValidGlyph || !CGRectContainsPoint(CGRectInset(glyphRect, -ASTextKitRendererGlyphTouchHitSlop, -ASTextKitRendererGlyphTouchHitSlop), currentPoint)) {
        continue;
      }

      block(characterIndex, [self.shadower offsetRectWithInternalRect:glyphRect], &stop);
    }
  }
}

- (CGRect)trailingRect
{
  __block CGRect trailingRect = CGRectNull;
  [self.context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    CGSize calculatedSize = textContainer.size;
    // If have an empty string, then our whole bounds constitute trailing space.
    if ([textStorage length] == 0) {
      trailingRect = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
      return;
    }

    // Take everything after our final character as trailing space.
    NSRange textRange = NSMakeRange([textStorage length] - 1, 1);
    NSArray *finalRects = [self unlockedRectsForTextRange:textRange measureOptions:ASTextKitRendererMeasureOptionLineHeight layoutManager:layoutManager textStorage:textStorage textContainer:textContainer];
    CGRect finalGlyphRect = [[finalRects lastObject] CGRectValue];
    CGPoint origin = CGPointMake(CGRectGetMaxX(finalGlyphRect), CGRectGetMinY(finalGlyphRect));
    CGSize size = CGSizeMake(calculatedSize.width - origin.x, calculatedSize.height - origin.y);
    trailingRect = (CGRect){origin, size};
  }];
  return trailingRect;
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  __block CGRect textRect = CGRectNull;
  [self.context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    // Bail on invalid range.
    if (NSMaxRange(textRange) > [textStorage length]) {
      ASDisplayNodeCFailAssert(@"Invalid range");
      return;
    }

    // Force glyph generation and layout.
    [layoutManager ensureLayoutForTextContainer:textContainer];

    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:textRange actualCharacterRange:NULL];
    textRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  }];
  return textRect;
}

@end
