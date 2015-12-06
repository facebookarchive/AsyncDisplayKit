/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTextNodeWordKerner.h"

#import <UIKit/UIKit.h>

#import "ASTextNodeTypes.h"

@implementation ASTextNodeWordKerner

#pragma mark - NSLayoutManager Delegate
- (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)properties characterIndexes:(const NSUInteger *)characterIndexes font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange
{
  NSUInteger glyphCount = glyphRange.length;
  NSGlyphProperty *newGlyphProperties = NULL;

  BOOL usesWordKerning = NO;

  // If our typing attributes specify word kerning, specify the spaces as whitespace control characters so we can customize their width.
  // Are any of the characters spaces?
  NSString *textStorageString = layoutManager.textStorage.string;
  for (NSUInteger arrayIndex = 0; arrayIndex < glyphCount; arrayIndex++) {
    NSUInteger characterIndex = characterIndexes[arrayIndex];
    if ([textStorageString characterAtIndex:characterIndex] != ' ')
      continue;

    // If we've set the whitespace control character for this space already, we have nothing to do.
    if (properties[arrayIndex] == NSGlyphPropertyControlCharacter) {
      usesWordKerning = YES;
      continue;
    }

    // Create new glyph properties, if necessary.
    if (!newGlyphProperties) {
      newGlyphProperties = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphCount);
      memcpy(newGlyphProperties, properties, (sizeof(NSGlyphProperty) * glyphCount));
    }

    // It's a space. Make it a whitespace control character.
    newGlyphProperties[arrayIndex] = NSGlyphPropertyControlCharacter;
  }

  // If we don't have any custom glyph properties, return 0 to indicate to the layout manager that it should use the standard glyphs+properties.
  if (!newGlyphProperties) {
    if (usesWordKerning) {
      // If the text does use word kerning we have to make sure we return the correct glyphCount, or the layout manager will just use the default properties and ignore our kerning.
      [layoutManager setGlyphs:glyphs properties:properties characterIndexes:characterIndexes font:aFont forGlyphRange:glyphRange];
      return glyphCount;
    } else {
      return 0;
    }
  }

  // Otherwise, use our custom glyph properties.
  [layoutManager setGlyphs:glyphs properties:newGlyphProperties characterIndexes:characterIndexes font:aFont forGlyphRange:glyphRange];
  free(newGlyphProperties);

  return glyphCount;
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager shouldUseAction:(NSControlCharacterAction)defaultAction forControlCharacterAtIndex:(NSUInteger)characterIndex
{
  // If it's a space character and we have custom word kerning, use the whitespace action control character.
  if ([layoutManager.textStorage.string characterAtIndex:characterIndex] == ' ')
    return NSControlCharacterWhitespaceAction;

  return defaultAction;
}

- (CGRect)layoutManager:(NSLayoutManager *)layoutManager boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex forTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)proposedRect glyphPosition:(CGPoint)glyphPosition characterIndex:(NSUInteger)characterIndex
{
  CGFloat wordKernedSpaceWidth = [self _wordKernedSpaceWidthForCharacterAtIndex:characterIndex atGlyphPosition:glyphPosition forTextContainer:textContainer layoutManager:layoutManager];
  return CGRectMake(glyphPosition.x, glyphPosition.y, wordKernedSpaceWidth, CGRectGetHeight(proposedRect));
}

- (CGFloat)_wordKernedSpaceWidthForCharacterAtIndex:(NSUInteger)characterIndex atGlyphPosition:(CGPoint)glyphPosition forTextContainer:(NSTextContainer *)textContainer layoutManager:(NSLayoutManager *)layoutManager
{
  // We use a map table for pointer equality and non-copying keys.
  static NSMapTable *spaceSizes;
  // NSMapTable is a defined thread unsafe class, so we need to synchronize
  // access in a light manner.  So we use dispatch_sync on this queue for all
  // access to the map table.
  static dispatch_queue_t mapQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    spaceSizes = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory capacity:1];
    mapQueue = dispatch_queue_create("org.AsyncDisplayKit.wordKerningQueue", DISPATCH_QUEUE_SERIAL);
  });
  CGFloat ordinarySpaceWidth;
  UIFont *font = [layoutManager.textStorage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
  CGFloat wordKerning = [[layoutManager.textStorage attribute:ASTextNodeWordKerningAttributeName atIndex:characterIndex effectiveRange:NULL] floatValue];
  __block NSNumber *ordinarySpaceSizeValue;
  dispatch_sync(mapQueue, ^{
    ordinarySpaceSizeValue = [spaceSizes objectForKey:font];
  });
  if (ordinarySpaceSizeValue == nil) {
    ordinarySpaceWidth = [@" " sizeWithAttributes:@{ NSFontAttributeName : font }].width;
    dispatch_async(mapQueue, ^{
      [spaceSizes setObject:@(ordinarySpaceWidth) forKey:font];
    });
  } else {
    ordinarySpaceWidth = [ordinarySpaceSizeValue floatValue];
  }

  CGFloat totalKernedWidth = (ordinarySpaceWidth + wordKerning);

  // TextKit normally handles whitespace by increasing the advance of the previous glyph, rather than displaying an
  // actual glyph for the whitespace itself.  However, in order to implement word kerning, we explicitly require a
  // discrete glyph whose bounding box we can specify.  The problem is that TextKit does not know this glyph is
  // invisible. From TextKit's perspective, this whitespace glyph is a glyph that MUST be displayed. Thus when it
  // comes to determining linebreaks, the width of this trailing whitespace glyph is considered. This causes
  // our text to wrap sooner than it otherwise would, as room is allocated at the end of each line for a glyph that
  // isn't actually visible.  To implement our desired behavior, we check to see if the current whitespace glyph
  // would break to the next line.  If it breaks to the next line, then this constitutes trailing whitespace, and
  // we specify enough room to fill up the remainder of the line, but nothing more.
  if (glyphPosition.x + totalKernedWidth > textContainer.size.width) {
    return (textContainer.size.width - glyphPosition.x);
  }

  return totalKernedWidth;
}

@end
