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

void ASLayoutElementValidateLayout(ASLayout *layout) {
    ASLayoutElementValidation *validation = [[ASLayoutElementValidation alloc] init];
    [validation registerValidator:[[ASLayoutElementStaticValidator alloc] init]];
    [validation registerValidator:[[ASLayoutElementStackValidator alloc] init]];
    [validation validateLayout:layout];
}

#pragma mark - Helpers

static NSString *ASLayoutValidationWrappingAssertMessage(SEL selector, id obj, Class cl) {
  return [NSString stringWithFormat:@"%@ was set on %@. It is either unecessary or the node needs to be wrapped in a %@", NSStringFromSelector(selector), obj, NSStringFromClass(cl)];
}

#pragma mark - ASLayoutElementBlockValidator

@implementation ASLayoutElementBlockValidator

#pragma mark Lifecycle

- (instancetype)initWithBlock:(ASLayoutElementBlockValidatorBlock)block
{
  self = [super init];
  if (self) {
    _block = [block copy];
  }
  return self;
}

#pragma mark <ASLayoutElementValidator>

- (void)validateLayout:(ASLayout *)layout
{
  if (self.block) {
    self.block(layout);
  }
}

@end

#pragma mark - ASLayoutElementStaticValidator

@implementation ASLayoutElementStaticValidator

- (void)validateLayout:(ASLayout *)layout
{
  for (ASLayout *sublayout in layout.sublayouts) {
    id<ASLayoutElement> layoutElement = layout.layoutElement;
    id<ASLayoutElement> sublayoutLayoutElement = sublayout.layoutElement;
    
    NSString *assertMessage = nil;
    Class stackContainerClass = [ASStaticLayoutSpec class];
    
    // Check for default layoutPosition
    if (!CGPointEqualToPoint(sublayoutLayoutElement.style.layoutPosition, CGPointZero)) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(layoutPosition), sublayoutLayoutElement, stackContainerClass);
    }
    
    // Sublayout layoutElement should be wrapped in a ASStaticLayoutSpec
    if (assertMessage == nil || [layoutElement isKindOfClass:stackContainerClass]) {
      continue;
    }
    
    ASDisplayNodeCAssert(NO, assertMessage);
  }
}

@end


#pragma mark - ASLayoutElementStackValidator

@implementation ASLayoutElementStackValidator

#pragma mark <ASLayoutElementValidator>

- (void)validateLayout:(ASLayout *)layout
{
  id<ASLayoutElement> layoutElement = layout.layoutElement;
  for (ASLayout *sublayout in layout.sublayouts) {
    id<ASLayoutElement> sublayoutLayoutElement = sublayout.layoutElement;
    
    NSString *assertMessage = nil;
    Class stackContainerClass = [ASStackLayoutSpec class];
    
    // Check if default values related to ASStackLayoutSpec have changed
    if (sublayoutLayoutElement.style.spacingBefore != 0) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(spacingBefore), sublayoutLayoutElement, stackContainerClass);
    } else if (sublayoutLayoutElement.style.spacingAfter != 0) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(spacingAfter), sublayoutLayoutElement, stackContainerClass);
    } else if (sublayoutLayoutElement.style.flexGrow == YES) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexGrow), sublayoutLayoutElement, stackContainerClass);
    } else if (sublayoutLayoutElement.style.flexShrink == YES) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexShrink), sublayoutLayoutElement, stackContainerClass);
    } else if (!ASDimensionEqualToDimension(sublayoutLayoutElement.style.flexBasis, ASDimensionAuto) ) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(flexBasis), sublayoutLayoutElement, stackContainerClass);
    } else if (sublayoutLayoutElement.style.alignSelf != ASStackLayoutAlignSelfAuto) {
      assertMessage = ASLayoutValidationWrappingAssertMessage(@selector(alignSelf), sublayoutLayoutElement, stackContainerClass);
    }
    
    // Sublayout layoutElement should be wrapped in a ASStackLayoutSpec
    if (assertMessage == nil || [layoutElement isKindOfClass:stackContainerClass]) {
      continue;
    }
    
    ASDisplayNodeCAssert(NO, assertMessage);
  }
}

@end

#pragma mark ASLayoutElementPreferredSizeValidator

@implementation ASLayoutElementPreferredSizeValidator

#pragma mark <ASLayoutElementValidator>

- (void)validateLayout:(ASLayout *)layout
{
  // TODO: Implement validation that certain node classes need to have a preferredSize set e.g. ASVideoNode
}

@end


#pragma mark - ASLayoutElementValidation

@interface ASLayoutElementValidation ()
@end

@implementation ASLayoutElementValidation {
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

- (NSArray<id<ASLayoutElementValidator>> *)validators
{
  return [_validators copy];
}

- (void)registerValidator:(id<ASLayoutElementValidator>)validator
{
  [_validators addObject:validator];
}

- (id<ASLayoutElementValidator>)registerValidatorWithBlock:(ASLayoutElementBlockValidatorBlock)block
{
  ASLayoutElementBlockValidator *blockValidator = [[ASLayoutElementBlockValidator alloc] initWithBlock:block];
  [_validators addObject:blockValidator];
  return blockValidator;
}

- (void)unregisterValidator:(id<ASLayoutElementValidator>)validator
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
    for (id<ASLayoutElementValidator> validator in self.validators) {
      [validator validateLayout:layout];
    }
    
    // Push sublayouts to queue for validation
    for (id sublayout in [layout sublayouts]) {
      queue.push(sublayout);
    }
    
  }
}

@end
