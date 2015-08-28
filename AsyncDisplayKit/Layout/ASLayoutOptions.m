//
//  ASLayoutOptions.m
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 8/27/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASLayoutOptions.h"

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import "ASInternalHelpers.h"
#import <objc/runtime.h>

@implementation ASLayoutOptions

static Class gDefaultLayoutOptionsClass = nil;
+ (void)setDefaultLayoutOptionsClass:(Class)defaultLayoutOptionsClass
{
  gDefaultLayoutOptionsClass = defaultLayoutOptionsClass;
}

+ (Class)defaultLayoutOptionsClass
{
  return gDefaultLayoutOptionsClass;
}


- (instancetype)initWithLayoutable:(id<ASLayoutable>)layoutable;
{
  self = [super init];
  if (self) {
    [self setupDefaults];
    [self setValuesFromLayoutable:layoutable];
#if DEBUG
    [self addObserver:self forKeyPath:@"changeMonitor"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
#endif
  }
  return self;
}

#if DEBUG
+ (NSSet *)keyPathsForValuesAffectingChangeMonitor
{
  NSMutableSet *keys = [NSMutableSet set];
  unsigned int count;
  
  objc_property_t *properties = class_copyPropertyList([self class], &count);
  for (size_t i = 0; i < count; ++i) {
    NSString *property = [NSString stringWithCString:property_getName(properties[i]) encoding:NSASCIIStringEncoding];
    
    if ([property isEqualToString: @"observableSelf"] == NO) {
      [keys addObject: property];
    }
  }
  free(properties);
  
  return keys;
}

#endif

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#if DEBUG
  if ([keyPath isEqualToString:@"changeMonitor"]) {
    ASDisplayNodeAssert(self.isMutable, @"You cannot alter this class once it is marked as immutable");
  } else
#endif
  {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}


#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
  ASLayoutOptions *copy = [[[self class] alloc] init];

  copy.flexBasis = self.flexBasis;
  copy.spacingAfter = self.spacingAfter;
  copy.spacingBefore = self.spacingBefore;
  copy.flexGrow = self.flexGrow;
  copy.flexShrink = self.flexShrink;
  
  copy.ascender = self.ascender;
  copy.descender = self.descender;

  copy.sizeRange = self.sizeRange;
  copy.layoutPosition = self.layoutPosition;

  return copy;
}

#pragma mark - Defaults
- (void)setupDefaults
{
  _flexBasis = ASRelativeDimensionUnconstrained;
  _spacingBefore = 0;
  _spacingAfter = 0;
  _flexGrow = NO;
  _flexShrink = NO;
  _alignSelf = ASStackLayoutAlignSelfAuto;

  _ascender = 0;
  _descender = 0;
  
  _sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero));
  _layoutPosition = CGPointZero;
}

// Do this here instead of in Node/Spec subclasses so that custom specs can set default values
- (void)setValuesFromLayoutable:(id<ASLayoutable>)layoutable
{
  if ([layoutable isKindOfClass:[ASTextNode class]]) {
    ASTextNode *textNode = (ASTextNode *)layoutable;
    self.ascender = round([[textNode.attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * ASScreenScale())/ASScreenScale();
    self.descender = round([[textNode.attributedString attribute:NSFontAttributeName atIndex:textNode.attributedString.length - 1 effectiveRange:NULL] descender] * ASScreenScale())/ASScreenScale();
  }
  if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    ASDisplayNode *displayNode = (ASDisplayNode *)layoutable;
    self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize), ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize));
    self.layoutPosition = displayNode.frame.origin;
  }
}


@end
