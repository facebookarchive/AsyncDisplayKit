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

#pragma mark - Sizing

- (CGSize)size
{
  if (!_sizeIsCalculated) {
    [self _calculateSize];
    _sizeIsCalculated = YES;
  }
  return _calculatedSize;
}

- (void)setConstrainedSize:(CGSize)constrainedSize
{
  if (!CGSizeEqualToSize(constrainedSize, _constrainedSize)) {
    _sizeIsCalculated = NO;
    _constrainedSize = constrainedSize;
    _calculatedSize = CGSizeZero;
    
    // Throw away the all subcomponents to create them with the new constrained size new as well as let the
    // truncater do it's job again for the new constrained size. This is necessary as after a truncation did happen
    // the context would use the truncated string and not the original string to truncate based on the new
    // constrained size
    __block ASTextKitContext *ctx = _context;
    __block ASTextKitTailTruncater *tru = _truncater;
    __block ASTextKitFontSizeAdjuster *adj = _fontSizeAdjuster;
    _context = nil;
    _truncater = nil;
    _fontSizeAdjuster = nil;
    ASPerformBlockOnDeallocationQueue(^{
      ctx = nil;
      tru = nil;
      adj = nil;
    });
  }
}

- (void)_calculateSize
{
  // if we have no scale factors or an unconstrained width, there is no reason to try to adjust the font size
  if (isinf(_constrainedSize.width) == NO && [_attributes.pointSizeScaleFactors count] > 0) {
    _currentScaleFactor = [[self fontSizeAdjuster] scaleFactor];
  }
  
  __block NSTextStorage *scaledTextStorage = nil;
  BOOL isScaled = [self isScaled];
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
  
  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by
  // -usedRectForTextContainer:).
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    [layoutManager ensureLayoutForTextContainer:textContainer];
  }];
  
  CGRect constrainedRect = {CGPointZero, _constrainedSize};
  __block CGRect boundingRect;
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
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
  CGSize boundingSize = [_shadower outsetSizeWithInsetSize:boundingRect.size];
  _calculatedSize = CGSizeMake(boundingSize.width, boundingSize.height);
}

- (BOOL)isScaled
{
  return (self.currentScaleFactor > 0 && self.currentScaleFactor < 1.0);
}

#pragma mark - Drawing

- (void)drawInContext:(CGContextRef)context bounds:(CGRect)bounds;
{
  // We add an assertion so we can track the rare conditions where a graphics context is not present
  ASDisplayNodeAssertNotNil(context, @"This is no good without a context.");
  
  // This renderer may not be the one that did the sizing. If that is the case its truncation and currentScaleFactor may not have been evaluated.
  // If there's any possibility we need to truncate or scale (e.g. width is not infinite, perform the size calculation.
  if (_sizeIsCalculated == NO && isinf(_constrainedSize.width) == NO) {
    [self _calculateSize];
  }

  CGRect shadowInsetBounds = [[self shadower] insetRectWithConstrainedRect:bounds];

  CGContextSaveGState(context);
  [[self shadower] setShadowInContext:context];
  UIGraphicsPushContext(context);

  LOG(@"%@, shadowInsetBounds = %@",self, NSStringFromCGRect(shadowInsetBounds));
  
  [[self context] performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    
    NSTextStorage *scaledTextStorage = nil;
    BOOL isScaled = [self isScaled];

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
