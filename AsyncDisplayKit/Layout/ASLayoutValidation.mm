/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutValidation.h"
#import "ASLayout.h"
#import "ASDisplayNode.h"

#import "ASStaticLayoutSpec.h"
#import "ASStackLayoutSpec.h"

#import <queue>

#pragma mark ASLayoutableBlockValidator

@implementation ASLayoutableBlockValidator

#pragma mark Lifecycle

- (instancetype)initWithBlock:(ASLayoutableBlockValidatorBlock)block
{
  self = [super init];
  if (self) {
    _block = [block copy];
  }
  return self;
}

#pragma mark <ASLayoutableValidator>

- (void)validateLayout:(ASLayout *)layout
{
  if (self.block) {
    self.block(layout);
  }
}

@end

#pragma mark ASLayoutableStaticValidator

@implementation ASLayoutableStaticValidator

- (void)validateLayout:(ASLayout *)layout
{
  id<ASLayoutable> layoutable = layout.layoutableObject;
  for (ASLayout * sublayout in layout.sublayouts) {
    id<ASLayoutable> sublayoutLayoutable = sublayout.layoutableObject;
    
    // Check for default sizeRange and layoutPosition
    ASRelativeSizeRange sizeRange = sublayoutLayoutable.sizeRange;
    ASRelativeSizeRange zeroSizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero),
                                                                ASRelativeSizeMakeWithCGSize(CGSizeZero));
    
    // Currently setting the preferredFrameSize also updates the sizeRange. Create a size range based on the
    // preferredFrameSize and check it if it's the same as the current sizeRange to be sure it was not changed manually
    CGSize preferredFrameSize = CGSizeZero;
    if ([sublayoutLayoutable respondsToSelector:@selector(preferredFrameSize)]) {
      preferredFrameSize = [((ASDisplayNode *)sublayoutLayoutable) preferredFrameSize];
    }
    ASRelativeSizeRange preferredFrameSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(preferredFrameSize);
    
    if ((ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, zeroSizeRange) ||
         ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, preferredFrameSizeRange))
        && CGPointEqualToPoint(sublayoutLayoutable.layoutPosition, CGPointZero)) {
      continue;
    }
    
    // Sublayout layoutable needs to be wrapped in a ASStaticLayoutSpec
    if ([layoutable isKindOfClass:[ASStaticLayoutSpec class]]) {
      continue;
    }

    ASDisplayNodeCAssert(NO, @"A property was set that requires the ASLayoutable to be wrapped in a ASStaticLayoutSpec");
  }
}

@end

#pragma mark ASLayoutableStackValidator

@implementation ASLayoutableStackValidator

#pragma mark <ASLayoutableValidator>

- (void)validateLayout:(ASLayout *)layout
{
  id<ASLayoutable> layoutable = layout.layoutableObject;
  for (ASLayout *sublayout in layout.sublayouts) {
    id<ASLayoutable> sublayoutLayoutable = sublayout.layoutableObject;
    
    // Check if default values related to ASStackLayoutSpec have changed
    if (sublayoutLayoutable.spacingBefore == 0 &&
        sublayoutLayoutable.spacingAfter == 0 &&
        !sublayoutLayoutable.flexGrow &&
        !sublayoutLayoutable.flexShrink &&
        ASRelativeDimensionEqualToRelativeDimension([sublayoutLayoutable flexBasis], ASRelativeDimensionUnconstrained) &&
        sublayoutLayoutable.alignSelf == ASStackLayoutAlignSelfAuto)
    {
      continue;
    }
    
    // Sublayout layoutable needs to be wrapped in a ASStackLayoutSpec
    if ([layoutable isKindOfClass:[ASStackLayoutSpec class]]) {
      continue;
    }
    
    ASDisplayNodeCAssert(NO, @"A property was set that requires the ASLayoutable to be wrapped in a ASStackLayoutSpec");
  }
}

@end

#pragma mark ASLayoutablePreferredSizeValidator

@implementation ASLayoutablePreferredSizeValidator

#pragma mark <ASLayoutableValidator>

- (void)validateLayout:(ASLayout *)layout
{
  // TODO: Implement validation that certain node classes need to have a preferredSize set e.g. ASVideoNode
}

@end


#pragma mark - ASLayoutableValidation

@interface ASLayoutableValidation ()
@property (copy, nonatomic) NSMutableArray<id<ASLayoutableValidator>> *validators;
@end

@implementation ASLayoutableValidation

#pragma mark Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self) {
    _validators = [NSMutableArray array];
  }
  return self;
}

#pragma mark Validator Management

- (void)registerValidator:(id<ASLayoutableValidator>)validator
{
  [self.validators addObject:validator];
}

- (id<ASLayoutableValidator>)registerValidatorWithBlock:(ASLayoutableBlockValidatorBlock)block
{
  ASLayoutableBlockValidator *blockValidator = [[ASLayoutableBlockValidator alloc] initWithBlock:block];
  [self.validators addObject:blockValidator];
  return blockValidator;
}

- (void)unregisterValidator:(id<ASLayoutableValidator>)validator
{
  [self.validators removeObject:validator];
}

#pragma mark Validation Process

- (void)validateLayout:(ASLayout *)layout
{
  // Queue used to keep track of sublayouts while traversing this layout in a BFS fashion.
  std::queue<ASLayout *> queue;
  queue.push(layout);
  
  while (!queue.empty()) {
    layout = queue.front();
    queue.pop();
    
    // Validate layout with all registered validators
    for (id<ASLayoutableValidator> validator in self.validators) {
      [validator validateLayout:layout];
    }
    
    // Push sublayouts to queue for validation
    for (id sublayout in [layout sublayouts]) {
      queue.push(sublayout);
    }
    
  }
}

@end
