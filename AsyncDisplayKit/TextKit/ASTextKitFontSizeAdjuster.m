//
//  ASTextKitFontSizeAdjuster.m
//  AsyncDisplayKit
//
//  Created by Luke on 1/20/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASTextKitContext.h"
#import "ASTextKitFontSizeAdjuster.h"

@implementation ASTextKitFontSizeAdjuster
{
  __weak ASTextKitContext *_context;
  CGFloat _minimumScaleFactor;
}

- (instancetype)initWithContext:(ASTextKitContext *)context
             minimumScaleFactor:(CGFloat)minimumScaleFactor
                constrainedSize:(CGSize)constrainedSize
{
  if (self = [super init]) {
    _context = context;
    _minimumScaleFactor = minimumScaleFactor;
    _constrainedSize = constrainedSize;
  }
  return self;
}

- (CGSize)sizeForAttributedString:(NSAttributedString *)attrString
{
  return [attrString boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  context:nil].size;
}


- (void) adjustFontSizeForAttributeString:(NSMutableAttributedString *)attrString withScaleFactor:(CGFloat)scaleFactor
{
  {
    [attrString beginEditing];

    [attrString enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, attrString.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {

      UIFont* font = value;
      font = [font fontWithSize:font.pointSize * scaleFactor];

      [attrString removeAttribute:NSFontAttributeName range:range];
      [attrString addAttribute:NSFontAttributeName value:font range:range];
    }];

    [attrString endEditing];
  }
}


- (void)adjustFontSize
{
  if (_minimumScaleFactor <= 0 || _minimumScaleFactor >= 1) {
    return;
  }
  [_context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    NSString *str = textStorage.string;
    NSArray *words = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *longestWordNeedingResize = @"";
    for (NSString *word in words) {
      if ([word length] > [longestWordNeedingResize length]) {
        longestWordNeedingResize = word;
      }
    }

    if ([longestWordNeedingResize length] == 0) {
      return;
    }

    NSRange range = [str rangeOfString:longestWordNeedingResize];
    NSMutableAttributedString *attrString = [textStorage attributedSubstringFromRange:range].mutableCopy;
    CGSize defaultSize = [self sizeForAttributedString:attrString];

    if (defaultSize.width > _constrainedSize.width) {
      [attrString removeAttribute:NSParagraphStyleAttributeName range:NSMakeRange(0, [attrString length])];
      NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
      context.minimumScaleFactor = _minimumScaleFactor;
      [attrString boundingRectWithSize:CGSizeMake(_constrainedSize.width, defaultSize.height)
                               options:NSStringDrawingUsesLineFragmentOrigin
                               context:context];

      [self adjustFontSizeForAttributeString:attrString withScaleFactor:context.actualScaleFactor];

      if ([self sizeForAttributedString:attrString].width <= _constrainedSize.width) {
        [self adjustFontSizeForAttributeString:textStorage withScaleFactor:context.actualScaleFactor];
        NSLog(@"ASTextKitFontSizeAdjuster : adjusted \"%@\"to fontsize actualScaleFactor:%f", longestWordNeedingResize, context.actualScaleFactor);
      }
    }
  }];
}

@end
