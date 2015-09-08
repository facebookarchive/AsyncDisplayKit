/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutOptions.h"

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import "ASInternalHelpers.h"

@interface ASLayoutOptions()
{
  ASDN::RecursiveMutex _propertyLock;
}
@end

@implementation ASLayoutOptions

@synthesize spacingBefore = _spacingBefore;
@synthesize spacingAfter = _spacingAfter;
@synthesize flexGrow = _flexGrow;
@synthesize flexShrink = _flexShrink;
@synthesize flexBasis = _flexBasis;
@synthesize alignSelf = _alignSelf;

@synthesize ascender = _ascender;
@synthesize descender = _descender;

@synthesize sizeRange = _sizeRange;
@synthesize layoutPosition = _layoutPosition;

static Class gDefaultLayoutOptionsClass = nil;
+ (void)setDefaultLayoutOptionsClass:(Class)defaultLayoutOptionsClass
{
  gDefaultLayoutOptionsClass = defaultLayoutOptionsClass;
}

+ (Class)defaultLayoutOptionsClass
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (gDefaultLayoutOptionsClass == nil) {
      // If someone is asking for this and it hasn't been customized yet, use the default.
      gDefaultLayoutOptionsClass = [ASLayoutOptions class];
    }
  });
  return gDefaultLayoutOptionsClass;
}

- (instancetype)init
{
  return [self initWithLayoutable:nil];
}

- (instancetype)initWithLayoutable:(id<ASLayoutable>)layoutable;
{
  self = [super init];
  if (self) {
    [self setupDefaults];
    [self setValuesFromLayoutable:layoutable];
  }
  return self;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
  ASLayoutOptions *copy = [[[self class] alloc] init];
  [self copyIntoOptions:copy];
  return copy;
}

- (void)copyIntoOptions:(ASLayoutOptions *)copy
{
  ASDN::MutexLocker l(_propertyLock);
  copy.flexBasis = self.flexBasis;
  copy.spacingAfter = self.spacingAfter;
  copy.spacingBefore = self.spacingBefore;
  copy.flexGrow = self.flexGrow;
  copy.flexShrink = self.flexShrink;
  
  copy.ascender = self.ascender;
  copy.descender = self.descender;
  
  copy.sizeRange = self.sizeRange;
  copy.layoutPosition = self.layoutPosition;
}


#pragma mark - Defaults
- (void)setupDefaults
{
  self.flexBasis = ASRelativeDimensionUnconstrained;
  self.spacingBefore = 0;
  self.spacingAfter = 0;
  self.flexGrow = NO;
  self.flexShrink = NO;
  self.alignSelf = ASStackLayoutAlignSelfAuto;

  self.ascender = 0;
  self.descender = 0;
  
  self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero));
  self.layoutPosition = CGPointZero;
}

// Do this here instead of in Node/Spec subclasses so that custom specs can set default values
- (void)setValuesFromLayoutable:(id<ASLayoutable>)layoutable
{
  ASDN::MutexLocker l(_propertyLock);
  if ([layoutable isKindOfClass:[ASTextNode class]]) {
    ASTextNode *textNode = (ASTextNode *)layoutable;
    if (textNode.attributedString.length > 0) {
      self.ascender = round([[textNode.attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * ASScreenScale())/ASScreenScale();
      self.descender = round([[textNode.attributedString attribute:NSFontAttributeName atIndex:textNode.attributedString.length - 1 effectiveRange:NULL] descender] * ASScreenScale())/ASScreenScale();
    }
  }
  if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    ASDisplayNode *displayNode = (ASDisplayNode *)layoutable;
    self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize), ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize));
    self.layoutPosition = displayNode.frame.origin;
  }
}

- (CGFloat)spacingAfter
{
  ASDN::MutexLocker l(_propertyLock);
  return _spacingAfter;
}

- (void)setSpacingAfter:(CGFloat)spacingAfter
{
  ASDN::MutexLocker l(_propertyLock);
  _spacingAfter = spacingAfter;
}

- (CGFloat)spacingBefore
{
  ASDN::MutexLocker l(_propertyLock);
  return _spacingBefore;
}

- (void)setSpacingBefore:(CGFloat)spacingBefore
{
  ASDN::MutexLocker l(_propertyLock);
  _spacingBefore = spacingBefore;
}

- (BOOL)flexGrow
{
  ASDN::MutexLocker l(_propertyLock);
  return _flexGrow;
}

- (void)setFlexGrow:(BOOL)flexGrow
{
  ASDN::MutexLocker l(_propertyLock);
  _flexGrow = flexGrow;
}

- (BOOL)flexShrink
{
  ASDN::MutexLocker l(_propertyLock);
  return _flexShrink;
}

- (void)setFlexShrink:(BOOL)flexShrink
{
  ASDN::MutexLocker l(_propertyLock);
  _flexShrink = flexShrink;
}

- (ASRelativeDimension)flexBasis
{
  ASDN::MutexLocker l(_propertyLock);
  return _flexBasis;
}

- (void)setFlexBasis:(ASRelativeDimension)flexBasis
{
  ASDN::MutexLocker l(_propertyLock);
  _flexBasis = flexBasis;
}

- (ASStackLayoutAlignSelf)alignSelf
{
  ASDN::MutexLocker l(_propertyLock);
  return _alignSelf;
}

- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf
{
  ASDN::MutexLocker l(_propertyLock);
  _alignSelf = alignSelf;
}

- (CGFloat)ascender
{
  ASDN::MutexLocker l(_propertyLock);
  return _ascender;
}

- (void)setAscender:(CGFloat)ascender
{
  ASDN::MutexLocker l(_propertyLock);
  _ascender = ascender;
}

- (CGFloat)descender
{
  ASDN::MutexLocker l(_propertyLock);
  return _descender;
}

- (void)setDescender:(CGFloat)descender
{
  ASDN::MutexLocker l(_propertyLock);
  _descender = descender;
}

- (ASRelativeSizeRange)sizeRange
{
  ASDN::MutexLocker l(_propertyLock);
  return _sizeRange;
}

- (void)setSizeRange:(ASRelativeSizeRange)sizeRange
{
  ASDN::MutexLocker l(_propertyLock);
  _sizeRange = sizeRange;
}

- (CGPoint)layoutPosition
{
  ASDN::MutexLocker l(_propertyLock);
  return _layoutPosition;
}

- (void)setLayoutPosition:(CGPoint)layoutPosition
{
  ASDN::MutexLocker l(_propertyLock);
  _layoutPosition = layoutPosition;
}

@end
