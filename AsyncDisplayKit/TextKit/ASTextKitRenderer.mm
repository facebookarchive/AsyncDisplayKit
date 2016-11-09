//
//  ASTextKitRenderer.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitRenderer.h"

#import "ASAssert.h"

#import "ASTextKitContext.h"
#import "ASTextKitShadower.h"
#import "ASTextKitTailTruncater.h"
#import "ASTextKitFontSizeAdjuster.h"
#import "ASInternalHelpers.h"
#import "ASRunLoopQueue.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

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
@synthesize attributes = _attributes, context = _context, shadower = _shadower, truncater = _truncater, fontSizeAdjuster = _fontSizeAdjuster;

#pragma mark - Initialization

- (instancetype)initWithTextKitAttributes:(const ASTextKitAttributes &)attributes
                          constrainedSize:(const CGSize)constrainedSize
{
  if (self = [super init]) {
    _constrainedSize = constrainedSize;
    _attributes = attributes;
    _sizeIsCalculated = NO;
    _currentScaleFactor = 1;
  }
  return self;
}

- (ASTextKitShadower *)shadower
{
  if (!_shadower) {
    ASTextKitAttributes attributes = _attributes;
    _shadower = [ASTextKitShadower shadowerWithShadowOffset:attributes.shadowOffset
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
    NSCharacterSet *avoidTailTruncationSet = attributes.avoidTailTruncationSet ? : _defaultAvoidTruncationCharacterSet();
    _truncater = [[ASTextKitTailTruncater alloc] initWithContext:[self context]
                                      truncationAttributedString:attributes.truncationAttributedString
                                          avoidTailTruncationSet:avoidTailTruncationSet];
  }
  return _truncater;
}

- (ASTextKitFontSizeAdjuster *)fontSizeAdjuster
{
  if (!_fontSizeAdjuster) {
    ASTextKitAttributes attributes = _attributes;
    // We must inset the constrained size by the size of the shadower.
    CGSize shadowConstrainedSize = [[self shadower] insetSizeWithConstrainedSize:_constrainedSize];
    _fontSizeAdjuster = [[ASTextKitFontSizeAdjuster alloc] initWithContext:[self context]
                                                           constrainedSize:shadowConstrainedSize
                                                         textKitAttributes:attributes];
  }
  return _fontSizeAdjuster;
}

- (ASTextKitContext *)context
{
  if (!_context) {
    ASTextKitAttributes attributes = _attributes;
    // We must inset the constrained size by the size of the shadower.
    CGSize shadowConstrainedSize = [[self shadower] insetSizeWithConstrainedSize:_constrainedSize];
    _context = [[ASTextKitContext alloc] initWithAttributedString:attributes.attributedString
                                                    lineBreakMode:attributes.lineBreakMode
                                             maximumNumberOfLines:attributes.maximumNumberOfLines
                                                   exclusionPaths:attributes.exclusionPaths
                                                  constrainedSize:shadowConstrainedSize];
  }
  return _context;
}

- (NSStringDrawingContext *)stringDrawingContext
{
  // String drawing contexts are not safe to use from more than one thread.
  // i.e. if they are created on one thread, it is unsafe to use them on another.
  // Therefore we always need to create a new one.
  //
  // http://web.archive.org/web/20140703122636/https://developer.apple.com/library/ios/documentation/uikit/reference/NSAttributedString_UIKit_Additions/Reference/Reference.html
  NSStringDrawingContext *stringDrawingContext = [[NSStringDrawingContext alloc] init];
  
  if (isinf(_constrainedSize.width) == NO && _attributes.maximumNumberOfLines > 0) {
    ASDisplayNodeAssert(_attributes.maximumNumberOfLines != 1, @"Max line count 1 is not supported in fast-path.");
    [stringDrawingContext setValue:@(_attributes.maximumNumberOfLines) forKey:@"maximumNumberOfLines"];
  }
  return stringDrawingContext;
}

#pragma mark - Sizing

- (CGSize)size
{
  if (!_sizeIsCalculated) {
    [self _calculateSize];
    _sizeIsCalculated = YES;
  }
  return _calculatedSize;
}

- (void)_calculateSize
{
  // if we have no scale factors or an unconstrained width, there is no reason to try to adjust the font size
  if (isinf(_constrainedSize.width) == NO && [_attributes.pointSizeScaleFactors count] > 0) {
    _currentScaleFactor = [[self fontSizeAdjuster] scaleFactor];
  }

  // If we do not scale, do exclusion, or do custom truncation, we should just use NSAttributedString drawing for a fast-path.
  if (self.canUseFastPath) {
    CGRect rect = [_attributes.attributedString boundingRectWithSize:_constrainedSize options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine context:self.stringDrawingContext];
    // Intersect with constrained rect, in case text kit goes out-of-bounds.
    rect = CGRectIntersection(rect, {CGPointZero, _constrainedSize});
    _calculatedSize = [self.shadower outsetSizeWithInsetSize:rect.size];
    return;
  }

  BOOL isScaled = [self isScaled];
  __block NSTextStorage *scaledTextStorage = nil;
  if (isScaled) {
    // apply the string scale before truncating or else we may truncate the string after we've done the work to shrink it.
    [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
      NSMutableAttributedString *scaledString = [[NSMutableAttributedString alloc] initWithAttributedString:textStorage];
      [ASTextKitFontSizeAdjuster adjustFontSizeForAttributeString:scaledString withScaleFactor:_currentScaleFactor];
      scaledTextStorage = [[NSTextStorage alloc] initWithAttributedString:scaledString];
      
      [textStorage removeLayoutManager:layoutManager];
      [scaledTextStorage addLayoutManager:layoutManager];
    }];
  }
  
  [[self truncater] truncate];
  
  CGRect constrainedRect = {CGPointZero, _constrainedSize};
  __block CGRect boundingRect;

  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by
  // -usedRectForTextContainer:).
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    [layoutManager ensureLayoutForTextContainer:textContainer];
    boundingRect = [layoutManager usedRectForTextContainer:textContainer];
    if (isScaled) {
      // put the non-scaled version back
      [scaledTextStorage removeLayoutManager:layoutManager];
      [textStorage addLayoutManager:layoutManager];
    }
  }];
  
  // TextKit often returns incorrect glyph bounding rects in the horizontal direction, so we clip to our bounding rect
  // to make sure our width calculations aren't being offset by glyphs going beyond the constrained rect.
  boundingRect = CGRectIntersection(boundingRect, {.size = constrainedRect.size});
  _calculatedSize = [_shadower outsetSizeWithInsetSize:boundingRect.size];
}

- (BOOL)isScaled
{
  return (_currentScaleFactor > 0 && _currentScaleFactor < 1.0);
}

- (BOOL)usesCustomTruncation
{
  // NOTE: This code does not correctly handle if they set `…` with different attributes.
  return _attributes.avoidTailTruncationSet != nil || [_attributes.truncationAttributedString.string isEqualToString:@"\u2026"] == NO;
}

- (BOOL)usesExclusionPaths
{
  return _attributes.exclusionPaths.count > 0;
}

- (BOOL)canUseFastPath
{
  return NO;
//  Fast path is temporarily disabled, because it's crashing in production.
//  NOTE: Remember to re-enable testFastPathTruncation when we re-enable this.
//  return self.isScaled == NO
//    && self.usesCustomTruncation == NO
//    && self.usesExclusionPaths == NO
//    // NSAttributedString drawing methods ignore usesLineFragmentOrigin if max line count 1,
//    // rendering them useless:
//    && (_attributes.maximumNumberOfLines != 1 || isinf(_constrainedSize.width));
}

#pragma mark - Drawing

- (void)drawInContext:(CGContextRef)context bounds:(CGRect)bounds;
{
  // We add an assertion so we can track the rare conditions where a graphics context is not present
  ASDisplayNodeAssertNotNil(context, @"This is no good without a context.");
  
  // This renderer may not be the one that did the sizing. If that is the case its truncation and currentScaleFactor may not have been evaluated.
  // If there's any possibility we need to truncate or scale (i.e. width is not infinite), perform the size calculation.
  if (_sizeIsCalculated == NO && isinf(_constrainedSize.width) == NO) {
    [self _calculateSize];
  }

  bounds = CGRectIntersection(bounds, { .size = _constrainedSize });
  CGRect shadowInsetBounds = [[self shadower] insetRectWithConstrainedRect:bounds];

  CGContextSaveGState(context);
  [[self shadower] setShadowInContext:context];
  UIGraphicsPushContext(context);

  LOG(@"%@, shadowInsetBounds = %@",self, NSStringFromCGRect(shadowInsetBounds));

  // If we use default options, we can use NSAttributedString for a
  // fast path.
  if (self.canUseFastPath) {
    CGRect drawingBounds = shadowInsetBounds;
    // Add a fudge-factor to the height, to workaround a bug in iOS 7
    if (AS_AT_LEAST_IOS8 == NO) {
      drawingBounds.size.height += 3;
    }
    [_attributes.attributedString drawWithRect:drawingBounds options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine context:self.stringDrawingContext];
  } else {
    BOOL isScaled = [self isScaled];
    [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
      
      NSTextStorage *scaledTextStorage = nil;

      if (isScaled) {
        // if we are going to scale the text, swap out the non-scaled text for the scaled version.
        NSMutableAttributedString *scaledString = [[NSMutableAttributedString alloc] initWithAttributedString:textStorage];
        [ASTextKitFontSizeAdjuster adjustFontSizeForAttributeString:scaledString withScaleFactor:_currentScaleFactor];
        scaledTextStorage = [[NSTextStorage alloc] initWithAttributedString:scaledString];
        
        [textStorage removeLayoutManager:layoutManager];
        [scaledTextStorage addLayoutManager:layoutManager];
      }
      
      LOG(@"usedRect: %@", NSStringFromCGRect([layoutManager usedRectForTextContainer:textContainer]));

      NSRange glyphRange = [layoutManager glyphRangeForBoundingRect:CGRectMake(0,0,textContainer.size.width, textContainer.size.height) inTextContainer:textContainer];
      LOG(@"boundingRect: %@", NSStringFromCGRect([layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer]));
      
      [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:shadowInsetBounds.origin];
      [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:shadowInsetBounds.origin];
      
      if (isScaled) {
        // put the non-scaled version back
        [scaledTextStorage removeLayoutManager:layoutManager];
        [textStorage addLayoutManager:layoutManager];
      }
    }];
  }

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
  ASTextKitTailTruncater *truncater = [self truncater];
  [truncater truncate];
  return truncater.visibleRanges;
}

@end

@implementation ASTextKitRenderer (ASTextKitRendererConvenience)

- (NSRange)firstVisibleRange
{
  std::vector<NSRange> visibleRanges = self.visibleRanges;
  if (visibleRanges.size() > 0) {
    return visibleRanges[0];
  }
  
  return NSMakeRange(0, 0);
}

@end
