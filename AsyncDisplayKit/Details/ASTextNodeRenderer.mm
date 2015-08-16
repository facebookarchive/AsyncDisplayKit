/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTextNodeRenderer.h"

#import <CoreText/CoreText.h>

#import "ASAssert.h"
#import "ASTextNodeTextKitHelpers.h"
#import "ASTextNodeWordKerner.h"
#import "ASThread.h"

static const CGFloat ASTextNodeRendererGlyphTouchHitSlop = 5.0;
static const CGFloat ASTextNodeRendererTextCapHeightPadding = 1.3;

@interface ASTextNodeRenderer ()

@end

@implementation ASTextNodeRenderer {
  CGSize _constrainedSize;
  CGSize _calculatedSize;

  NSAttributedString *_attributedString;
  NSAttributedString *_truncationString;
  NSLineBreakMode _truncationMode;
  NSUInteger _maximumLineCount;
  NSRange _truncationCharacterRange;
  NSRange _visibleRange;

  ASTextNodeWordKerner *_wordKerner;

  ASDN::RecursiveMutex _textKitLock;
  NSLayoutManager *_layoutManager;
  NSTextStorage *_textStorage;
  NSTextContainer *_textContainer;

  NSArray *_exclusionPaths;
}

#pragma mark - Initialization

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                        truncationString:(NSAttributedString *)truncationString
                          truncationMode:(NSLineBreakMode)truncationMode
                        maximumLineCount:(NSUInteger)maximumLineCount
                          exclusionPaths:(NSArray *)exclusionPaths
                         constrainedSize:(CGSize)constrainedSize
{
  if (self = [super init]) {
    _attributedString = attributedString;
    _truncationString = truncationString;
    _truncationMode = truncationMode;
    _truncationCharacterRange = NSMakeRange(NSNotFound, truncationString.length);
    
    _maximumLineCount = maximumLineCount;

    _exclusionPaths = exclusionPaths;

    _constrainedSize = constrainedSize;
  }
  return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                        truncationString:(NSAttributedString *)truncationString
                          truncationMode:(NSLineBreakMode)truncationMode
                        maximumLineCount:(NSUInteger)maximumLineCount
                         constrainedSize:(CGSize)constrainedSize
{
  return [self initWithAttributedString:attributedString truncationString:truncationString truncationMode:truncationMode maximumLineCount:maximumLineCount exclusionPaths:nil constrainedSize:constrainedSize];
}

/*
 * Use this method to lazily construct the TextKit components.
 */
- (void)_initializeTextKitComponentsIfNeeded
{
  ASDN::MutexLocker l(_textKitLock);

  if (_layoutManager == nil) {
    [self _initializeTextKitComponentsWithAttributedString:_attributedString];
  }
}

- (void)_initializeTextKitComponentsWithAttributedString:(NSAttributedString *)attributedString
{
  ASDN::MutexLocker l(_textKitLock);

  // Concurrently initialising TextKit components crashes (rdar://18448377) so we use a global lock.  :(
  static ASDN::StaticMutex mutex = ASDISPLAYNODE_MUTEX_INITIALIZER;
  ASDN::StaticMutexLocker gl(mutex);

  // Create the TextKit component stack with our default configuration.
  _textStorage = (attributedString ? [[NSTextStorage alloc] initWithAttributedString:attributedString] : [[NSTextStorage alloc] init]);
  _layoutManager = [[NSLayoutManager alloc] init];
  _layoutManager.usesFontLeading = NO;
  _wordKerner = [[ASTextNodeWordKerner alloc] init];
  _layoutManager.delegate = _wordKerner;
  [_textStorage addLayoutManager:_layoutManager];
  _textContainer = [[NSTextContainer alloc] initWithSize:_constrainedSize];
  // We want the text laid out up to the very edges of the container.
  _textContainer.lineFragmentPadding = 0;
  // Translate our truncation mode into a line break mode on the container
  _textContainer.lineBreakMode = _truncationMode;
  // Set maximum number of lines
  _textContainer.maximumNumberOfLines = _maximumLineCount;

  _textContainer.exclusionPaths = _exclusionPaths;

  [_layoutManager addTextContainer:_textContainer];

  ASDN::StaticMutexUnlocker gu(mutex);

  [self _invalidateLayout];
}

#pragma mark - Layout Initialization

- (void)_invalidateLayout
{
  ASDN::MutexLocker l(_textKitLock);

  // Force a layout, which means we have to recompute our truncation parameters
  NSInteger originalStringLength = _textStorage.string.length;

  [self _calculateSize];

  NSRange visibleGlyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
  _visibleRange = [_layoutManager characterRangeForGlyphRange:visibleGlyphRange actualGlyphRange:NULL];

  // Check if text is truncated, and if so apply our truncation string
  if (_visibleRange.length < originalStringLength && _truncationString.length > 0) {
    NSInteger firstCharacterIndexToReplace = [self _calculateCharacterIndexBeforeTruncationMessage];
    if (firstCharacterIndexToReplace == 0 || firstCharacterIndexToReplace == NSNotFound) {
      // Something went horribly wrong, short-circuit
      [self _calculateSize];
      return;
    }

    // Update/truncate the visible range of text
    _visibleRange = NSMakeRange(0, firstCharacterIndexToReplace);
    NSRange truncationReplacementRange = NSMakeRange(firstCharacterIndexToReplace, _textStorage.length - firstCharacterIndexToReplace);
    // Replace the end of the visible message with the truncation string
    [_textStorage replaceCharactersInRange:truncationReplacementRange
                      withAttributedString:_truncationString];

    _truncationCharacterRange = NSMakeRange(firstCharacterIndexToReplace, _truncationString.length);

    // We must recompute the calculated size because we may have changed it in
    // changing the string
    [self _calculateSize];
  }
}

#pragma mark - Sizing

/*
 * Calculates the size of the text in the renderer based on the parameters
 * stored in the ivars of this class.
 *
 * This method can be expensive, so it is important that it not be called
 * frequently.  It not only sizes the text, but it also configures the TextKit
 * components for drawing, and responding to all other queries made to this
 * class.
 */
- (void)_calculateSize
{
  ASDN::MutexLocker l(_textKitLock);

  if (_attributedString.length == 0) {
    _calculatedSize = CGSizeZero;
    return;
  }
    
  [self _initializeTextKitComponentsIfNeeded];

  // Force glyph generation and layout, which may not have happened yet (and
  // isn't triggered by -usedRectForTextContainer:).
  [_layoutManager ensureLayoutForTextContainer:_textContainer];

  CGRect constrainedRect = CGRect{CGPointZero, _constrainedSize};
  CGRect boundingRect = [_layoutManager usedRectForTextContainer:_textContainer];

  // TextKit often returns incorrect glyph bounding rects in the horizontal
  // direction, so we clip to our bounding rect to make sure our width
  // calculations aren't being offset by glyphs going beyond the constrained
  // rect.
  boundingRect = CGRectIntersection(boundingRect, (CGRect){.size = constrainedRect.size});

  _calculatedSize = boundingRect.size;
}

- (CGSize)size
{
  [self _initializeTextKitComponentsIfNeeded];

  return _calculatedSize;
}

#pragma mark - Layout

- (CGRect)trailingRect
{
  ASDN::MutexLocker l(_textKitLock);

  [self _initializeTextKitComponentsIfNeeded];

  // If have an empty string, then our whole bounds constitute trailing space.
  if ([_textStorage length] == 0) {
    return CGRectMake(0, 0, _calculatedSize.width, _calculatedSize.height);
  }

  // Take everything after our final character as trailing space.
  NSArray *finalRects = [self rectsForTextRange:NSMakeRange([_textStorage length] - 1, 1) measureOption:ASTextNodeRendererMeasureOptionLineHeight];
  CGRect finalGlyphRect = [[finalRects lastObject] CGRectValue];
  CGPoint origin = CGPointMake(CGRectGetMaxX(finalGlyphRect), CGRectGetMinY(finalGlyphRect));
  CGSize size = CGSizeMake(_calculatedSize.width - origin.x, _calculatedSize.height - origin.y);
  return (CGRect){origin, size};
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  ASDN::MutexLocker l(_textKitLock);

  [self _initializeTextKitComponentsIfNeeded];

  // Bail on invalid range.
  if (NSMaxRange(textRange) > [_textStorage length]) {
    ASDisplayNodeAssertNotNil(nil, @"Invalid range");
    return CGRectZero;
  }

  // Force glyph generation and layout.
  [_layoutManager ensureLayoutForTextContainer:_textContainer];

  NSRange glyphRange = [_layoutManager glyphRangeForCharacterRange:textRange actualCharacterRange:NULL];
  CGRect textRect = [_layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textContainer];
  return textRect;
}

- (NSArray *)rectsForTextRange:(NSRange)textRange
                 measureOption:(ASTextNodeRendererMeasureOption)measureOption
{
  ASDN::MutexLocker l(_textKitLock);

  [self _initializeTextKitComponentsIfNeeded];

  BOOL textRangeIsValid = (NSMaxRange(textRange) <= [_textStorage length]);
  ASDisplayNodeAssertTrue(textRangeIsValid);
  if (!textRangeIsValid) {
    return @[];
  }

  // Used for block measure option
  __block CGRect firstRect = CGRectNull;
  __block CGRect lastRect = CGRectNull;
  __block CGRect blockRect = CGRectNull;
  NSMutableArray *textRects = [NSMutableArray array];

  NSString *string = _textStorage.string;

  NSRange totalGlyphRange = [_layoutManager glyphRangeForCharacterRange:textRange actualCharacterRange:NULL];

  [_layoutManager enumerateLineFragmentsForGlyphRange:totalGlyphRange usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *textContainer, NSRange glyphRange, BOOL *stop) {

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
        CGRect properGlyphRect = [self _rectForGlyphAtIndex:i measureOption:measureOption];

        // Don't count empty glyphs towards our line rect.
        if (!CGRectIsEmpty(properGlyphRect)) {
          lineRect = CGRectIsNull(lineRect) ? properGlyphRect
                                            : CGRectUnion(lineRect, properGlyphRect);
        }
      }
    }

    if (!CGRectIsNull(lineRect)) {
      if (measureOption == ASTextNodeRendererMeasureOptionBlock) {
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
        [textRects addObject:[NSValue valueWithCGRect:lineRect]];
      }
    }
  }];

  if (measureOption == ASTextNodeRendererMeasureOptionBlock) {
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

      [textRects addObject:[NSValue valueWithCGRect:firstRect]];
    }
    if (!CGRectIsNull(blockRect)) {
      [textRects addObject:[NSValue valueWithCGRect:blockRect]];
    }
    if (!CGRectIsNull(lastRect)) {
      [textRects addObject:[NSValue valueWithCGRect:lastRect]];
    }
  }

  return textRects;
}

- (CGRect)_rectForGlyphAtIndex:(NSUInteger)glyphIndex
                 measureOption:(ASTextNodeRendererMeasureOption)measureOption
{
  ASDN::MutexLocker l(_textKitLock);

  NSUInteger charIndex = [_layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  CGGlyph glyph = [_layoutManager glyphAtIndex:glyphIndex];
  CTFontRef font = (__bridge_retained CTFontRef)[_textStorage attribute:NSFontAttributeName
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

  CGRect glyphRect = [_layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                               inTextContainer:_textContainer];

  // If it is a NSTextAttachment, we don't have the matched glyph and use width of glyphRect instead of advance.
  CGFloat advance = (glyph == kCGFontIndexInvalid) ? glyphRect.size.width : CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, NULL, 1);

  // We treat the center of the glyph's bounding box as the center of our new rect
  CGPoint glyphCenter = CGPointMake(CGRectGetMidX(glyphRect), CGRectGetMidY(glyphRect));

  CGRect properGlyphRect;
  if (measureOption == ASTextNodeRendererMeasureOptionCapHeight
      || measureOption == ASTextNodeRendererMeasureOptionBlock) {
    CGFloat ascent = CTFontGetAscent(font);
    CGFloat descent = CTFontGetDescent(font);
    CGFloat capHeight = CTFontGetCapHeight(font);
    CGFloat leading = CTFontGetLeading(font);
    CGFloat glyphHeight = ascent + descent;

    // For visual balance, we add the cap height padding above the cap, and
    // below the baseline, we scale by the descent so it grows with the size of
    // the text.
    CGFloat topPadding = ASTextNodeRendererTextCapHeightPadding * descent;
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

- (void)enumerateTextIndexesAtPosition:(CGPoint)position usingBlock:(as_renderer_index_block_t)block
{
  if (position.x > _constrainedSize.width
      || position.y > _constrainedSize.height
      || block == NULL) {
    // Short circuit if the position is outside the size of this renderer, or
    // if the block is null.
    return;
  }

  ASDN::MutexLocker l(_textKitLock);

  [self _initializeTextKitComponentsIfNeeded];

  // We break it up into a 44pt box for the touch, and find the closest link
  // attribute-containing glyph to the center of the touch.
  CGFloat squareSide = 44.f;
  // Should be odd if you want to test the center of the touch.
  NSInteger pointsOnASide = 3;

  // The distance between any 2 of the adjacent points
  CGFloat pointSeparation = squareSide / pointsOnASide;
  // These are for tracking which point we're on.  We start with -pointsOnASide/2
  // and go to pointsOnASide/2.  So if pointsOnASide=3, we go from -1 to 1.
  NSInteger endIndex = pointsOnASide / 2;
  NSInteger startIndex = -endIndex;

  BOOL stop = NO;
  for (NSInteger i = startIndex; i <= endIndex && !stop; i++) {
    for (NSInteger j = startIndex; j <= endIndex && !stop; j++) {
      CGPoint currentPoint = CGPointMake(position.x + i * pointSeparation,
                                         position.y + j * pointSeparation);

      // We ask the layout manager for the proper glyph at the touch point
      NSUInteger glyphIndex = [_layoutManager glyphIndexForPoint:currentPoint
                                                                  inTextContainer:_textContainer];

      // If it's an invalid glyph, quit.
      BOOL isValidGlyph = NO;
      [_layoutManager glyphAtIndex:glyphIndex isValidIndex:&isValidGlyph];
      if (!isValidGlyph) {
        continue;
      }

      NSUInteger characterIndex = [_layoutManager characterIndexForGlyphAtIndex:glyphIndex];

      CGRect glyphRect = [self _rectForGlyphAtIndex:glyphIndex
                                      measureOption:ASTextNodeRendererMeasureOptionLineHeight];

      // Sometimes TextKit plays jokes on us and returns glyphs that really
      // aren't close to the point in question.  Silly TextKit...
      if (!CGRectContainsPoint(CGRectInset(glyphRect, -ASTextNodeRendererGlyphTouchHitSlop, -ASTextNodeRendererGlyphTouchHitSlop), currentPoint)) {
        continue;
      }

      block(characterIndex, glyphRect, &stop);
    }
  }
}

#pragma mark - Truncation

/*
 * Calculates the intersection of the truncation message within the end of the
 * last line.
 *
 * This is accomplished by temporarily adding an exclusion rect for the size of
 * the truncation string at the end of the last line of text, and forcing the
 * layout manager to re-layout and clip the text such that we get a natural
 * clipping based on the settings of the layout manager.
 */
- (NSUInteger)_calculateCharacterIndexBeforeTruncationMessage
{
  ASDN::MutexLocker l(_textKitLock);

  CGRect constrainedRect = (CGRect){.size = _calculatedSize};

  NSRange visibleGlyphRange = [_layoutManager glyphRangeForBoundingRect:constrainedRect inTextContainer:_textContainer];
  NSInteger lastVisibleGlyphIndex = (NSMaxRange(visibleGlyphRange) - 1);
  CGRect lastLineRect = [_layoutManager lineFragmentRectForGlyphAtIndex:lastVisibleGlyphIndex effectiveRange:NULL];

  // Calculate the bounding rectangle for the truncation message
  ASTextKitComponents *truncationComponents = [ASTextKitComponents componentsWithAttributedSeedString:_truncationString
                                                                                    textContainerSize:constrainedRect.size];

  // Size the truncation message
  [truncationComponents.layoutManager ensureLayoutForTextContainer:truncationComponents.textContainer];
  NSRange truncationGlyphRange = [truncationComponents.layoutManager glyphRangeForTextContainer:truncationComponents.textContainer];
  CGRect truncationUsedRect = [truncationComponents.layoutManager boundingRectForGlyphRange:truncationGlyphRange inTextContainer:truncationComponents.textContainer];
  CGRect translatedTruncationRect = CGRectMake(CGRectGetMaxX(constrainedRect) - truncationUsedRect.size.width,
                                               CGRectGetMinY(lastLineRect),
                                               truncationUsedRect.size.width,
                                               truncationUsedRect.size.height);

  // Determine which glyph is the first to be clipped / overlaps the truncation message.
  CGPoint beginningOfTruncationMessage = CGPointMake(translatedTruncationRect.origin.x, CGRectGetMidY(translatedTruncationRect));
  NSUInteger firstClippedGlyphIndex = [_layoutManager glyphIndexForPoint:beginningOfTruncationMessage inTextContainer:_textContainer fractionOfDistanceThroughGlyph:NULL];
  NSUInteger firstCharacterIndexToReplace = [_layoutManager characterIndexForGlyphAtIndex:firstClippedGlyphIndex];
  ASDisplayNodeAssert(firstCharacterIndexToReplace != NSNotFound, @"The beginning of the truncation message exclusion rect (%@) didn't intersect any glyphs", NSStringFromCGPoint(beginningOfTruncationMessage));

  // Break on word boundaries
  return [self _findTruncationInsertionPointAtOrBeforeCharacterIndex:firstCharacterIndexToReplace];
}

+ (NSCharacterSet *)_truncationCharacterSet
{
  static NSCharacterSet *truncationCharacterSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *mutableCharacterSet = [[NSMutableCharacterSet alloc] init];
    [mutableCharacterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [mutableCharacterSet addCharactersInString:@".,!?:;"];
    truncationCharacterSet = mutableCharacterSet;
  });
  return truncationCharacterSet;
}

/**
  * @abstract Finds the first whitespace at or before the character index do we don't truncate in the middle of words
  * @discussion If there are multiple whitespaces together (say a space and a newline), this will backtrack to the first one
  */
- (NSUInteger)_findTruncationInsertionPointAtOrBeforeCharacterIndex:(NSUInteger)firstCharacterIndexToReplace
{
  ASDN::MutexLocker l(_textKitLock);
  // Don't attempt to truncate beyond the beginning of the string
  if (firstCharacterIndexToReplace >= _textStorage.length) {
    return 0;
  }

  // Find the glyph range of the line fragment containing the first character to replace.
  NSRange lineGlyphRange;
  [_layoutManager lineFragmentRectForGlyphAtIndex:[_layoutManager glyphIndexForCharacterAtIndex:firstCharacterIndexToReplace]
                                   effectiveRange:&lineGlyphRange];

  // Look for the first whitespace from the end of the line, starting from the truncation point
  NSUInteger startingSearchIndex = [_layoutManager characterIndexForGlyphAtIndex:lineGlyphRange.location];
  NSUInteger endingSearchIndex = firstCharacterIndexToReplace;
  NSRange rangeToSearch = NSMakeRange(startingSearchIndex, (endingSearchIndex - startingSearchIndex));

  NSCharacterSet *truncationCharacterSet = [[self class] _truncationCharacterSet];

  NSRange rangeOfLastVisibleWhitespace = [_textStorage.string rangeOfCharacterFromSet:truncationCharacterSet
                                                                              options:NSBackwardsSearch
                                                                                range:rangeToSearch];

  // Couldn't find a good place to truncate. Might be because there is no whitespace in the text, or we're dealing
  // with a foreign language encoding. Settle for truncating at the original place, which may be mid-word.
  if (rangeOfLastVisibleWhitespace.location == NSNotFound) {
    return firstCharacterIndexToReplace;
  } else {
    return rangeOfLastVisibleWhitespace.location;
  }
}

#pragma mark - Drawing

- (void)drawInRect:(CGRect)bounds inContext:(CGContextRef)context
{
  ASDisplayNodeAssert(context, @"This is no good without a context.");
  UIGraphicsPushContext(context);
  CGContextSaveGState(context);

  [self _initializeTextKitComponentsIfNeeded];
  NSRange glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
  {
    ASDN::MutexLocker l(_textKitLock);
    [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:bounds.origin];
    [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:bounds.origin];
  }

  CGContextRestoreGState(context);
  UIGraphicsPopContext();
}

#pragma mark - String Ranges

- (NSUInteger)lineCount
{
  ASDN::MutexLocker l(_textKitLock);
  [self _initializeTextKitComponentsIfNeeded];

  NSUInteger lineCount = 0;
  for (NSRange lineRange = { 0, 0 }; NSMaxRange(lineRange) < [_layoutManager numberOfGlyphs]; lineCount++) {
    [_layoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(lineRange) effectiveRange:&lineRange];
  }
  return lineCount;
}

- (NSRange)visibleRange
{
  ASDN::MutexLocker l(_textKitLock);
  [self _initializeTextKitComponentsIfNeeded];
  return _visibleRange;
}

- (NSRange)truncationStringCharacterRange
{
  ASDN::MutexLocker l(_textKitLock);
  [self _initializeTextKitComponentsIfNeeded];
  return _truncationCharacterRange;
}

@end
