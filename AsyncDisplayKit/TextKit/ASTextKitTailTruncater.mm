//
//  ASTextKitTailTruncater.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitContext.h"
#import "ASTextKitTailTruncater.h"

@implementation ASTextKitTailTruncater
{
  __weak ASTextKitContext *_context;
  NSAttributedString *_truncationAttributedString;
  NSCharacterSet *_avoidTailTruncationSet;
}
@synthesize visibleRanges = _visibleRanges;

- (instancetype)initWithContext:(ASTextKitContext *)context
     truncationAttributedString:(NSAttributedString *)truncationAttributedString
         avoidTailTruncationSet:(NSCharacterSet *)avoidTailTruncationSet
{
  if (self = [super init]) {
    _context = context;
    _truncationAttributedString = truncationAttributedString;
    _avoidTailTruncationSet = avoidTailTruncationSet;
  }
  return self;
}

/**
 Calculates the intersection of the truncation message within the end of the last line.
 */
- (NSUInteger)_calculateCharacterIndexBeforeTruncationMessage:(NSLayoutManager *)layoutManager
                                                  textStorage:(NSTextStorage *)textStorage
                                                textContainer:(NSTextContainer *)textContainer
{
  CGRect constrainedRect = (CGRect){ .size = textContainer.size };

  // Walk backward from the end of the last line, first by word and then by character,
  // measuring the last line until it fits in the constrained rect.
  // NOTE: Previously, we would measure the truncation string itself, and subtract
  // its width from the end of the line. This approach _is unreliable_ because it doesn't
  // account for kerning. For example, in "y…" the right edge of the y overlaps the ellipsis.

  NSMutableString *str = textStorage.mutableString;

  BOOL textStorageHasTruncationString = NO;
  NSCharacterSet *truncatableSet = [_avoidTailTruncationSet invertedSet];
  // Start at end of string
  while (YES) {
    NSRange visibleGlyphRange = [layoutManager glyphRangeForBoundingRect:constrainedRect
                                                         inTextContainer:textContainer];
    if (visibleGlyphRange.length == 0) {
      return NSNotFound;
    }
    NSInteger lastVisibleGlyphIndex = (NSMaxRange(visibleGlyphRange) - 1);
    NSInteger lastVisibleCharacterIndex = [layoutManager characterIndexForGlyphAtIndex:lastVisibleGlyphIndex];

    if (lastVisibleCharacterIndex == str.length - 1) {
      if (textStorageHasTruncationString) {
        NSUInteger length = str.length;
        [str deleteCharactersInRange:NSMakeRange(length - _truncationAttributedString.length, _truncationAttributedString.length)];
        return textStorage.length;
      } else {
        return NSNotFound;
      }
    }

    if (textStorageHasTruncationString) {
      NSUInteger length = str.length;
      [str deleteCharactersInRange:NSMakeRange(length - _truncationAttributedString.length, _truncationAttributedString.length)];
      textStorageHasTruncationString = NO;
    }

    // Find the next visible whitespace character
    NSUInteger nextTruncatableIndex = [str rangeOfCharacterFromSet:_avoidTailTruncationSet options:NSBackwardsSearch range:NSMakeRange(0, lastVisibleCharacterIndex)].location;
    if (nextTruncatableIndex != NSNotFound) {
      // Find the next letter before that one, without
      // crossing into any whitespace
      nextTruncatableIndex = [str rangeOfCharacterFromSet:truncatableSet options:NSBackwardsSearch range:NSMakeRange(0, nextTruncatableIndex)].location + 1;
    } else {
      // Fall back to just truncating wherever if no untruncatable characters are left (e.g. "Quali…").
      nextTruncatableIndex = MIN(lastVisibleCharacterIndex, str.length - 1);
    }

    // Put the truncation string in and we'll try again.
    [textStorage replaceCharactersInRange:NSMakeRange(nextTruncatableIndex, str.length - nextTruncatableIndex) withAttributedString:_truncationAttributedString];
    textStorageHasTruncationString = YES;
  }
}

- (void)truncate
{
  [_context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    NSUInteger originalStringLength = textStorage.length;

    [layoutManager ensureLayoutForTextContainer:textContainer];

    NSRange visibleGlyphRange = [layoutManager glyphRangeForBoundingRect:{ .size = textContainer.size }
                                                         inTextContainer:textContainer];
    NSRange visibleCharacterRange = [layoutManager characterRangeForGlyphRange:visibleGlyphRange
                                                              actualGlyphRange:NULL];

    // Check if text is truncated, and if so apply our truncation string
    if (visibleCharacterRange.length < originalStringLength && _truncationAttributedString.length > 0) {
      NSInteger firstCharacterIndexToReplace = [self _calculateCharacterIndexBeforeTruncationMessage:layoutManager
                                                                                         textStorage:textStorage
                                                                                       textContainer:textContainer];
      if (firstCharacterIndexToReplace == 0 || firstCharacterIndexToReplace == NSNotFound) {
        return;
      }

      // Update/truncate the visible range of text
      visibleCharacterRange = NSMakeRange(0, firstCharacterIndexToReplace);
      NSRange truncationReplacementRange = NSMakeRange(firstCharacterIndexToReplace,
                                                       textStorage.length - firstCharacterIndexToReplace);
      // Replace the end of the visible message with the truncation string
      [textStorage replaceCharactersInRange:truncationReplacementRange
                       withAttributedString:_truncationAttributedString];
    }

    _visibleRanges = { visibleCharacterRange };
  }];
}

- (NSRange)firstVisibleRange
{
  std::vector<NSRange> visibleRanges = _visibleRanges;
  if (visibleRanges.size() > 0) {
    return visibleRanges[0];
  }

  return NSMakeRange(NSNotFound, 0);
}

@end
