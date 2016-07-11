//
//  ASLayoutValidation.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutValidation.h"
#import "ASLayout.h"
#import "ASDisplayNode.h"

#import "ASStaticLayoutSpec.h"
#import "ASStackLayoutSpec.h"

#import <queue>

#pragma mark - Layout Validation

void ASLayoutableValidateLayout(ASLayout *layout) {
    ASLayoutableValidation *validation = [[ASLayoutableValidation alloc] init];
    [validation registerValidator:[[ASLayoutableStaticValidator alloc] init]];
    [validation registerValidator:[[ASLayoutableStackValidator alloc] init]];
    [validation validateLayout:layout];
}

#pragma mark - Helpers

static NSString *ASLayoutValidationWrappingAssertMessage(SEL selector, id obj, Class cl) {
  return [NSString stringWithFormat:@"%@ was set on %@. It is either unecessary or the node needs to be wrapped in a %@", NSStringFromSelector(selector), obj, NSStringFromClass(cl)];
}

#pragma mark - ASLayoutableBlockValidator

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

#pragma mark - ASLayoutableStaticValidator

@implementation ASLayoutableStaticValidator

- (void)validateLayout:(ASLayout *)layout
{
  for (ASLayout *sublayout in layout.sublayouts) {
    id<ASLayoutable> layoutable = layout.layoutableObject;
    id<ASLayoutable> sublayoutLayoutable = sublayout.layoutableObject;
    
    NSString *assertMessage = nil;
    Class stackContainerClass = [ASStaticLayoutSpec class];
    
    // Check for default sizeRange and layoutPosition
    ASRelativeSizeRange sizeRange = sublayoutLayoutable.sizeRange;
    ASRelativeSizeRange zeroSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeZero);
    
    // Currently setting the preferredFrameSize also updates the sizeRange. Create a size range based on the
    // preferredFrameSize and check it if it's the same as the current sizeRange to be sure it was not changed manually
    CGSize preferredFrameSize = CGSizeZero;
    if ([sublayoutLayoutable respondsToSelector:@selector(preferredFrameSize)]) {
      preferredFrameSize = [((ASDisplayNode *)sublayoutLayoutable) preferredFrameSize];
    }
    ASRelativeSizeRange preferredFrameSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(preferredFrameSize);
    
    if (ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, zeroSizeRange) == NO &&
        ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, preferredFrameSizeRange) == NO) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(sizeRange), sublayoutLayoutable, stackContainerClass);
    } else if (!CGPointEqualToPoint(sublayoutLayoutable.layoutPosition, CGPointZero)) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(layoutPosition), sublayoutLayoutable, stackContainerClass);
    }
    
    // Sublayout layoutable should be wrapped in a ASStaticLayoutSpec
    if (assertMessage == nil || [layoutable isKindOfClass:stackContainerClass]) {
      continue;
    }
    
    ASDisplayNodeCAssert(NO, assertMessage);
  }
}

@end


#pragma mark - ASLayoutableStackValidator

@implementation ASLayoutableStackValidator

#pragma mark <ASLayoutableValidator>

- (void)validateLayout:(ASLayout *)layout
{
  id<ASLayoutable> layoutable = layout.layoutableObject;
  for (ASLayout *sublayout in layout.sublayouts) {
    id<ASLayoutable> sublayoutLayoutable = sublayout.layoutableObject;
    
    NSString *assertMessage = nil;
    Class stackContainerClass = [ASStackLayoutSpec class];
    
    // Check if default values related to ASStackLayoutSpec have changed
    if (sublayoutLayoutable.spacingBefore != 0) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(spacingBefore), sublayoutLayoutable, stackContainerClass);
    } else if (sublayoutLayoutable.spacingAfter != 0) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(spacingAfter), sublayoutLayoutable, stackContainerClass);
    } else if (sublayoutLayoutable.flexGrow == YES) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexGrow), sublayoutLayoutable, stackContainerClass);
    } else if (sublayoutLayoutable.flexShrink == YES) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexShrink), sublayoutLayoutable, stackContainerClass);
    } else if (!ASRelativeDimensionEqualToRelativeDimension(sublayoutLayoutable.flexBasis, ASRelativeDimensionUnconstrained) ) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexBasis), sublayoutLayoutable, stackContainerClass);
    } else if (sublayoutLayoutable.alignSelf != ASStackLayoutAlignSelfAuto) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(alignSelf), sublayoutLayoutable, stackContainerClass);
    }
    
    // Sublayout layoutable should be wrapped in a ASStackLayoutSpec
    if (assertMessage == nil || [layoutable isKindOfClass:stackContainerClass]) {
      continue;
    }
    
    ASDisplayNodeCAssert(NO, assertMessage);
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
@end

@implementation ASLayoutableValidation {
  NSMutableArray *_validators;
}

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

- (NSArray<id<ASLayoutableValidator>> *)validators
{
  return [_validators copy];
}

- (void)registerValidator:(id<ASLayoutableValidator>)validator
{
  [_validators addObject:validator];
}

- (id<ASLayoutableValidator>)registerValidatorWithBlock:(ASLayoutableBlockValidatorBlock)block
{
  ASLayoutableBlockValidator *blockValidator = [[ASLayoutableBlockValidator alloc] initWithBlock:block];
  [_validators addObject:blockValidator];
  return blockValidator;
}

- (void)unregisterValidator:(id<ASLayoutableValidator>)validator
{
  [_validators removeObject:validator];
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
