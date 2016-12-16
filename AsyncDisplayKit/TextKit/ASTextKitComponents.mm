//
//  ASTextKitComponents.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitComponents.h"

#import <tgmath.h>

@interface ASTextKitComponents ()

// read-write redeclarations
@property (nonatomic, strong, readwrite) NSTextStorage *textStorage;
@property (nonatomic, strong, readwrite) NSTextContainer *textContainer;
@property (nonatomic, strong, readwrite) NSLayoutManager *layoutManager;

@end

@implementation ASTextKitComponents

+ (instancetype)componentsWithAttributedSeedString:(NSAttributedString *)attributedSeedString
                                 textContainerSize:(CGSize)textContainerSize
{
  NSTextStorage *textStorage = attributedSeedString ? [[NSTextStorage alloc] initWithAttributedString:attributedSeedString] : [[NSTextStorage alloc] init];

  return [self componentsWithTextStorage:textStorage
                       textContainerSize:textContainerSize
                           layoutManager:[[NSLayoutManager alloc] init]];
}

+ (instancetype)componentsWithTextStorage:(NSTextStorage *)textStorage
                        textContainerSize:(CGSize)textContainerSize
                            layoutManager:(NSLayoutManager *)layoutManager
{
  ASTextKitComponents *components = [[self alloc] init];

  components.textStorage = textStorage;

  components.layoutManager = layoutManager;
  [components.textStorage addLayoutManager:components.layoutManager];

  components.textContainer = [[NSTextContainer alloc] initWithSize:textContainerSize];
  components.textContainer.lineFragmentPadding = 0.0; // We want the text laid out up to the very edges of the text-view.
  [components.layoutManager addTextContainer:components.textContainer];

  return components;
}

- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth
{
  ASTextKitComponents *components = self;

  // If our text-view's width is already the constrained width, we can use our existing TextKit stack for this sizing calculation.
  // Otherwise, we create a temporary stack to size for `constrainedWidth`.
  if (CGRectGetWidth(components.textView.bounds) != constrainedWidth) {
    components = [ASTextKitComponents componentsWithAttributedSeedString:components.textStorage textContainerSize:CGSizeMake(constrainedWidth, CGFLOAT_MAX)];
  }

  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by -usedRectForTextContainer:).
  [components.layoutManager ensureLayoutForTextContainer:components.textContainer];
  CGSize textSize = [components.layoutManager usedRectForTextContainer:components.textContainer].size;

  return textSize;
}

- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth
                  forMaxNumberOfLines:(NSInteger)numberOfLines {
  
  ASTextKitComponents *components = self;
  
  
  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by - usedRectForTextContainer:).
  [components.layoutManager ensureLayoutForTextContainer:components.textContainer];
  
  // Calculate height baed on layoutManager
  CGSize textSize = [components.layoutManager usedRectForTextContainer:components.textContainer].size;
  CGFloat height = textSize.height;
  
  // Calculate height based on line fragments calculations
  NSRange lineRange = NSMakeRange(0, 0);
  NSUInteger numberOfGlyphs = components.layoutManager.numberOfGlyphs;
  CGRect fragmentRect = CGRectZero;
  CGFloat maxHeight = CGFLOAT_MAX;
  NSUInteger numLines = 0;
  
  NSUInteger index = 0;
  while (index < numberOfGlyphs) {
    fragmentRect = [components.layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
    index = NSMaxRange(lineRange);
    
    if (numLines == numberOfLines && numberOfLines != 0) {
      maxHeight = fragmentRect.origin.y + fragmentRect.size.height;
      break;
    }
    numLines += 1;
  }
    
  CGFloat fragmentHeight = fragmentRect.origin.y + fragmentRect.size.height;
  CGFloat finalHeight = std::ceil(std::fmax(std::fmin(maxHeight, height), fragmentHeight));
  
  CGSize size = CGSizeMake(textSize.width, finalHeight);
  
  return size;
}

@end
