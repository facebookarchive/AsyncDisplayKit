/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASTextKitRenderer.h"

#import "ASAssert.h"

#import "ASTextKitContext.h"
#import "ASTextKitShadower.h"
#import "ASTextKitTailTruncater.h"
#import "ASTextKitTruncating.h"

static NSCharacterSet *_defaultAvoidTruncationCharacterSet()
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

@implementation ASTextKitRenderer {
  CGSize _calculatedSize;
  BOOL _sizeIsCalculated;
}
@synthesize attributes = _attributes, context = _context, shadower = _shadower, truncater = _truncater;

#pragma mark - Initialization

- (instancetype)initWithTextKitAttributes:(const ASTextKitAttributes &)attributes
                          constrainedSize:(const CGSize)constrainedSize
{
  if (self = [super init]) {
    _constrainedSize = constrainedSize;
    _attributes = attributes;
    _sizeIsCalculated = NO;
  }
  return self;
}

- (ASTextKitShadower *)shadower
{
  if (!_shadower) {
    ASTextKitAttributes attributes = _attributes;
    _shadower = [[ASTextKitShadower alloc] initWithShadowOffset:attributes.shadowOffset
                                                    shadowColor:attributes.shadowColor
                                                  shadowOpacity:attributes.shadowOpacity
                                                   shadowRadius:attributes.shadowRadius];
  }
  return _shadower;
}

- (ASTextKitTailTruncater *)truncater
{
  if (!_truncater) {
    ASTextKitAttributes attributes = _attributes;
    // We must inset the constrained size by the size of the shadower.
    CGSize shadowConstrainedSize = [[self shadower] insetSizeWithConstrainedSize:_constrainedSize];
    _truncater = [[ASTextKitTailTruncater alloc] initWithContext:[self context]
                                      truncationAttributedString:attributes.truncationAttributedString
                                          avoidTailTruncationSet:attributes.avoidTailTruncationSet ?: _defaultAvoidTruncationCharacterSet()
                                                 constrainedSize:shadowConstrainedSize];
  }
  return _truncater;
}

- (ASTextKitContext *)context
{
  if (!_context) {
    ASTextKitAttributes attributes = _attributes;
    CGSize shadowConstrainedSize = [[self shadower] insetSizeWithConstrainedSize:_constrainedSize];
    _context = [[ASTextKitContext alloc] initWithAttributedString:attributes.attributedString
                                                    lineBreakMode:attributes.lineBreakMode
                                             maximumNumberOfLines:attributes.maximumNumberOfLines
                                                   exclusionPaths:attributes.exclusionPaths
                                                  constrainedSize:shadowConstrainedSize
                                             layoutManagerFactory:attributes.layoutManagerFactory];
  }
  return _context;
}

#pragma mark - Sizing

- (void)_calculateSize
{
  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by
  // -usedRectForTextContainer:).
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    [layoutManager ensureLayoutForTextContainer:textContainer];
  }];


  CGRect constrainedRect = {CGPointZero, _constrainedSize};
  __block CGRect boundingRect;
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    boundingRect = [layoutManager usedRectForTextContainer:textContainer];
  }];

  // TextKit often returns incorrect glyph bounding rects in the horizontal direction, so we clip to our bounding rect
  // to make sure our width calculations aren't being offset by glyphs going beyond the constrained rect.
  boundingRect = CGRectIntersection(boundingRect, {.size = constrainedRect.size});

  _calculatedSize = [_shadower outsetSizeWithInsetSize:boundingRect.size];
}

- (CGSize)size
{
  if (!_sizeIsCalculated) {
    [self _calculateSize];
    _sizeIsCalculated = YES;
  }
  return _calculatedSize;
}

#pragma mark - Drawing

- (void)drawInContext:(CGContextRef)context bounds:(CGRect)bounds;
{
  // We add an assertion so we can track the rare conditions where a graphics context is not present
  ASDisplayNodeAssertNotNil(context, @"This is no good without a context.");

  CGRect shadowInsetBounds = [[self shadower] insetRectWithConstrainedRect:bounds];

  CGContextSaveGState(context);
  [[self shadower] setShadowInContext:context];
  UIGraphicsPushContext(context);

  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
    [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:shadowInsetBounds.origin];
    [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:shadowInsetBounds.origin];
  }];

  UIGraphicsPopContext();
  CGContextRestoreGState(context);
}

#pragma mark - String Ranges

- (NSUInteger)lineCount
{
  __block NSUInteger lineCount = 0;
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    for (NSRange lineRange = { 0, 0 }; NSMaxRange(lineRange) < [layoutManager numberOfGlyphs]; lineCount++) {
      [layoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(lineRange) effectiveRange:&lineRange];
    }
  }];
  return lineCount;
}

- (std::vector<NSRange>)visibleRanges
{
  return [self truncater].visibleRanges;
}

@end
