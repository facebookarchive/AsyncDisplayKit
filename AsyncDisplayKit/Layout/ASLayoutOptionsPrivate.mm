/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutOptionsPrivate.h"
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import "ASThread.h"


/**
 *  Both an ASDisplayNode and an ASLayoutSpec conform to ASLayoutable. There are several properties
 *  in ASLayoutable that are used as layoutOptions when a node or spec is used in a layout spec.
 *  These properties are provided for convenience, as they are forwards to the node or spec's
 *  ASLayoutOptions class. Instead of duplicating the property forwarding in both classes, we 
 *  create a define that allows us to easily implement the forwards in one place.
 *
 *  If you create a custom layout spec, we recommend this stragety if you decide to extend
 *  ASDisplayNode and ASLAyoutSpec to provide convenience properties for any options that your 
 *  layoutSpec may require.
 */
#define ASLayoutOptionsForwarding \
- (ASLayoutOptions *)layoutOptions\
{\
ASDN::MutexLocker l(_layoutOptionsLock);\
if (_layoutOptions == nil) {\
_layoutOptions = [[[ASLayoutOptions defaultLayoutOptionsClass] alloc] initWithLayoutable:self];\
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
