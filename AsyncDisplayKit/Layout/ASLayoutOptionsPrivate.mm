//
//  ASDisplayNode+Layoutable.m
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 8/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASLayoutOptionsPrivate.h"
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>


#define ASLayoutOptionsForwarding \
- (ASLayoutOptions *)layoutOptions\
{\
if (_layoutOptions == nil) {\
_layoutOptions = [[[ASLayoutOptions defaultLayoutOptionsClass] alloc] init];\
}\
return _layoutOptions;\
}\
\
- (CGFloat)spacingBefore\
{\
return self.layoutOptions.spacingBefore;\
}\
\
- (void)setSpacingBefore:(CGFloat)spacingBefore\
{\
self.layoutOptions.spacingBefore = spacingBefore;\
}\
\
- (CGFloat)spacingAfter\
{\
return self.layoutOptions.spacingAfter;\
}\
\
- (void)setSpacingAfter:(CGFloat)spacingAfter\
{\
self.layoutOptions.spacingAfter = spacingAfter;\
}\
\
- (BOOL)flexGrow\
{\
return self.layoutOptions.flexGrow;\
}\
\
- (void)setFlexGrow:(BOOL)flexGrow\
{\
self.layoutOptions.flexGrow = flexGrow;\
}\
\
- (BOOL)flexShrink\
{\
return self.layoutOptions.flexShrink;\
}\
\
- (void)setFlexShrink:(BOOL)flexShrink\
{\
self.layoutOptions.flexShrink = flexShrink;\
}\
\
- (ASRelativeDimension)flexBasis\
{\
return self.layoutOptions.flexBasis;\
}\
\
- (void)setFlexBasis:(ASRelativeDimension)flexBasis\
{\
self.layoutOptions.flexBasis = flexBasis;\
}\
\
- (ASStackLayoutAlignSelf)alignSelf\
{\
return self.layoutOptions.alignSelf;\
}\
\
- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf\
{\
  self.layoutOptions.alignSelf = alignSelf;\
}\
\
- (CGFloat)ascender\
{\
  return self.layoutOptions.ascender;\
}\
\
- (void)setAscender:(CGFloat)ascender\
{\
  self.layoutOptions.ascender = ascender;\
}\
\
- (CGFloat)descender\
{\
  return self.layoutOptions.descender;\
}\
\
- (void)setDescender:(CGFloat)descender\
{\
  self.layoutOptions.descender = descender;\
}\
\
- (ASRelativeSizeRange)sizeRange\
{\
  return self.layoutOptions.sizeRange;\
}\
\
- (void)setSizeRange:(ASRelativeSizeRange)sizeRange\
{\
  self.layoutOptions.sizeRange = sizeRange;\
}\
\
- (CGPoint)layoutPosition\
{\
  return self.layoutOptions.layoutPosition;\
}\
\
- (void)setLayoutPosition:(CGPoint)position\
{\
  self.layoutOptions.layoutPosition = position;\
}\


@implementation ASDisplayNode(ASLayoutOptions)
ASLayoutOptionsForwarding
@end

@implementation ASLayoutSpec(ASLayoutOptions)
ASLayoutOptionsForwarding
@end
