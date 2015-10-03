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
    
    self.flexBasis = ASRelativeDimensionUnconstrained;
    self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero));
    self.layoutPosition = CGPointZero;
    
    // The following properties use a default value of 0 which we do not need to assign.
    // self.spacingBefore = 0;
    // self.spacingAfter = 0;
    // self.flexGrow = NO;
    // self.flexShrink = NO;
    // self.alignSelf = ASStackLayoutAlignSelfAuto;
    // self.ascender = 0;
    // self.descender = 0;
    
    [self setValuesFromLayoutable:layoutable];
  }
  return self;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
  ASLayoutOptions *copy = [[[self class] alloc] init];
  [copy copyFromOptions:self];
  return copy;
}

- (void)copyFromOptions:(ASLayoutOptions *)layoutOptions
{
  ASDN::MutexLocker l(_propertyLock);
  self.flexBasis = layoutOptions.flexBasis;
  self.spacingAfter = layoutOptions.spacingAfter;
  self.spacingBefore = layoutOptions.spacingBefore;
  self.flexGrow = layoutOptions.flexGrow;
  self.flexShrink = layoutOptions.flexShrink;
  self.alignSelf = layoutOptions.alignSelf;
  
  self.ascender = layoutOptions.ascender;
  self.descender = layoutOptions.descender;
  
  self.sizeRange = layoutOptions.sizeRange;
  self.layoutPosition = layoutOptions.layoutPosition;
}

/**
 *  Given an id<ASLayoutable>, set up layout options that are intrinsically defined by the layoutable.
 *
 *  While this could be done in the layoutable object itself, moving the logic into the ASLayoutOptions class 
 *  allows a custom spec to set up defaults without needing to alter the layoutable itself. For example,
 *  image you were creating a custom baseline spec that needed ascender/descender. To assign values automatically
 *  when a text node's attribute string is set, you would need to subclass ASTextNode and assign the values in the
 *  override of setAttributeString. However, assigning the defaults in an ASLayoutOptions subclass's
 *  setValuesFromLayoutable allows you to create a custom spec without the need to create a
 *  subclass of ASTextNode.
 *
 *  @param layoutable The layoutable object to inspect for default intrinsic layout option values
 */
- (void)setValuesFromLayoutable:(id<ASLayoutable>)layoutable
{
  ASDN::MutexLocker l(_propertyLock);
  if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    ASDisplayNode *displayNode = (ASDisplayNode *)layoutable;
    self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize), ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize));
    
    if ([layoutable isKindOfClass:[ASTextNode class]]) {
      ASTextNode *textNode = (ASTextNode *)layoutable;
      NSAttributedString *attributedString = textNode.attributedString;
      if (attributedString.length > 0) {
        CGFloat screenScale = ASScreenScale();
        self.ascender = round([[attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * screenScale)/screenScale;
        self.descender = round([[attributedString attribute:NSFontAttributeName atIndex:attributedString.length - 1 effectiveRange:NULL] descender] * screenScale)/screenScale;
      }
    }
    
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
