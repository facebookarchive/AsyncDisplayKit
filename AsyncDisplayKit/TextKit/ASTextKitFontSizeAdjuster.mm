//
//  ASTextKitFontSizeAdjuster.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitContext.h"
#import "ASTextKitFontSizeAdjuster.h"
#import "ASLayoutManager.h"

#import <mutex>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

@implementation ASTextKitFontSizeAdjuster
{
  __weak ASTextKitContext *_context;
  ASTextKitAttributes _attributes;
  std::mutex _textKitMutex;
  BOOL _measured;
  CGFloat _scaleFactor;
  NSLayoutManager *_sizingLayoutManager;
  NSTextContainer *_sizingTextContainer;
}

- (instancetype)initWithContext:(ASTextKitContext *)context
                constrainedSize:(CGSize)constrainedSize
              textKitAttributes:(const ASTextKitAttributes &)textComponentAttributes;
{
  if (self = [super init]) {
    _context = context;
    _constrainedSize = constrainedSize;
    _attributes = textComponentAttributes;
  }
  return self;
}

+ (void)adjustFontSizeForAttributeString:(NSMutableAttributedString *)attrString withScaleFactor:(CGFloat)scaleFactor
{
  [attrString beginEditing];

  // scale all the attributes that will change the bounding box
  [attrString enumerateAttributesInRange:NSMakeRange(0, attrString.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
    if (attrs[NSFontAttributeName] != nil) {
      UIFont *font = attrs[NSFontAttributeName];
      font = [font fontWithSize:roundf(font.pointSize * scaleFactor)];
      [attrString removeAttribute:NSFontAttributeName range:range];
      [attrString addAttribute:NSFontAttributeName value:font range:range];
    }
    
    if (attrs[NSKernAttributeName] != nil) {
      NSNumber *kerning = attrs[NSKernAttributeName];
      [attrString removeAttribute:NSKernAttributeName range:range];
      [attrString addAttribute:NSKernAttributeName value:@([kerning floatValue] * scaleFactor) range:range];
    }
    
    if (attrs[NSParagraphStyleAttributeName] != nil) {
      NSMutableParagraphStyle *paragraphStyle = [attrs[NSParagraphStyleAttributeName] mutableCopy];
      paragraphStyle.lineSpacing = (paragraphStyle.lineSpacing * scaleFactor);
      paragraphStyle.paragraphSpacing = (paragraphStyle.paragraphSpacing * scaleFactor);
      paragraphStyle.firstLineHeadIndent = (paragraphStyle.firstLineHeadIndent * scaleFactor);
      paragraphStyle.headIndent = (paragraphStyle.headIndent * scaleFactor);
      paragraphStyle.tailIndent = (paragraphStyle.tailIndent * scaleFactor);
      paragraphStyle.minimumLineHeight = (paragraphStyle.minimumLineHeight * scaleFactor);
      paragraphStyle.maximumLineHeight = (paragraphStyle.maximumLineHeight * scaleFactor);
      paragraphStyle.lineHeightMultiple = (paragraphStyle.lineHeightMultiple * scaleFactor);
      paragraphStyle.paragraphSpacing = (paragraphStyle.paragraphSpacing * scaleFactor);
      
      [attrString removeAttribute:NSParagraphStyleAttributeName range:range];
      [attrString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    }
    
  }];

  [attrString endEditing];
}

- (NSUInteger)lineCountForString:(NSAttributedString *)attributedString
{
    NSUInteger lineCount = 0;
    
    static std::mutex __static_mutex;
    std::lock_guard<std::mutex> l(__static_mutex);
    
    NSTextStorage *textStorage = _attributes.textStorageCreationBlock ? _attributes.textStorageCreationBlock(attributedString) : [[NSTextStorage alloc] initWithAttributedString:attributedString];
    if (_sizingLayoutManager == nil) {
        _sizingLayoutManager = _attributes.layoutManagerCreationBlock ? _attributes.layoutManagerCreationBlock() : [[ASLayoutManager alloc] init];
        _sizingLayoutManager.usesFontLeading = NO;
    }
    [textStorage addLayoutManager:_sizingLayoutManager];
    if (_sizingTextContainer == nil) {
        // make this text container unbounded in height so that the layout manager will compute the total
        // number of lines and not stop counting when height runs out.
        _sizingTextContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(_constrainedSize.width, FLT_MAX)];
        _sizingTextContainer.lineFragmentPadding = 0;
        
        // use 0 regardless of what is in the attributes so that we get an accurate line count
        _sizingTextContainer.maximumNumberOfLines = 0;
        [_sizingLayoutManager addTextContainer:_sizingTextContainer];
    }
    
    _sizingTextContainer.lineBreakMode = _attributes.lineBreakMode;
    _sizingTextContainer.exclusionPaths = _attributes.exclusionPaths;
    
    
    for (NSRange lineRange = { 0, 0 }; NSMaxRange(lineRange) < [_sizingLayoutManager numberOfGlyphs] && lineCount <= _attributes.maximumNumberOfLines; lineCount++) {
        [_sizingLayoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(lineRange) effectiveRange:&lineRange];
    }
    
    [textStorage removeLayoutManager:_sizingLayoutManager];
    return lineCount;
}

- (CGFloat)scaleFactor
{
  if (_measured) {
    return _scaleFactor;
  }
  
  if ([_attributes.pointSizeScaleFactors count] == 0 || isinf(_constrainedSize.width)) {
    _measured = YES;
    _scaleFactor = 1.0;
    return _scaleFactor;
  }
  
  __block CGFloat adjustedScale = 1.0;
  
  NSArray *scaleFactors = _attributes.pointSizeScaleFactors;
  [_context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    
    // Check for two different situations (and correct for both)
    // 1. The longest word in the string fits without being wrapped
    // 2. The entire text fits in the given constrained size.
    
    NSString *str = textStorage.string;
    NSArray *words = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *longestWordNeedingResize = @"";
    for (NSString *word in words) {
      if ([word length] > [longestWordNeedingResize length]) {
        longestWordNeedingResize = word;
      }
    }
    
    NSUInteger scaleIndex = 0;

    // find the longest word and make sure it fits in the constrained width
    if ([longestWordNeedingResize length] > 0) {
      
      NSRange longestWordRange = [str rangeOfString:longestWordNeedingResize];
      NSMutableAttributedString *attrString = [textStorage attributedSubstringFromRange:longestWordRange].mutableCopy;
      CGSize longestWordSize = [attrString boundingRectWithSize:CGSizeMake(FLT_MAX, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
      
      // check if the longest word is larger than our constrained width
      if (longestWordSize.width > _constrainedSize.width) {
        
        // we have a word that is too long. Loop through our scale factors until we fit
        for (NSNumber *scaleFactor in scaleFactors) {
          // even if we still don't fit, save this scaleFactor so more of the word will fit
          adjustedScale = [scaleFactor floatValue];
          
          // adjust here so we start at the proper place in our scale array if we have too many lines
          scaleIndex++;
          
          if (ceilf(longestWordSize.width * [scaleFactor floatValue])  <= _constrainedSize.width) {
            // we fit! we are done
            break;
          }
        }
      }
    }
    
    if (_attributes.maximumNumberOfLines > 0) {
      // get the number of lines in our possibly scaled string
      NSUInteger numberOfLines = [self lineCountForString:textStorage];
      if (numberOfLines > _attributes.maximumNumberOfLines) {
        
        for (NSUInteger index = scaleIndex; index < scaleFactors.count; index++) {
          NSMutableAttributedString *entireAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:textStorage];
          [[self class] adjustFontSizeForAttributeString:entireAttributedString withScaleFactor:[scaleFactors[index] floatValue]];
          
          
          // save away this scale factor. Even if we don't fit completely we should still scale down
          adjustedScale = [scaleFactors[index] floatValue];
          
          if ([self lineCountForString:entireAttributedString] <= _attributes.maximumNumberOfLines) {
            // we fit! we are done
            break;
          }
        }
        
      }
    }
    
  }];
  _measured = YES;
  _scaleFactor = adjustedScale;
  return _scaleFactor;
}

@end
