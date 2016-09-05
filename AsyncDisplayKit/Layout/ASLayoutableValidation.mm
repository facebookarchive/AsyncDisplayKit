//
//  ASLayoutableValidation.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutableValidation.h"
#import "ASLayout.h"
#import "ASDisplayNode.h"

#import "ASLayoutableValidationBlockProvider.h"
#import "ASStaticLayoutSpec.h"
#import "ASStackLayoutSpec.h"

NSString * const ASLayoutableValidationErrorDomain = @"ASLayoutableValidationErrorDomain";

#pragma mark - Helpers

static NSString *ASLayoutValidationWrappingErrorMessage(SEL selector, id obj, Class cl)
{
  return [NSString stringWithFormat:@"%@ was set on %@. It is either unecessary or the node needs to be wrapped in a %@", NSStringFromSelector(selector), obj, NSStringFromClass(cl)];
}

static NSError *ASLayoutableValidationErrorForMessage(NSString *message)
{
  NSDictionary *userInfo = @{
    NSLocalizedDescriptionKey: NSLocalizedString(message, nil)
  };
  return [NSError errorWithDomain:ASLayoutableValidationErrorDomain code:0 userInfo:userInfo];
}

#pragma mark - Validation Blocks

ASLayoutableValidationBlock ASLayoutableValidatorBlockRejectStackLayoutable()
{
  return ^(id<ASLayoutable> layoutable, NSError * __autoreleasing *error) {
    ASEnvironmentLayoutOptionsState defaultLayoutOptions = ASEnvironmentLayoutOptionsStateMakeDefault();
    
    // Check if default values related to ASStackLayoutSpec have changed
    Class layoutSpecClass = [ASStackLayoutSpec class];
    NSString *errorMessage = nil;
    if (layoutable.spacingBefore != defaultLayoutOptions.spacingBefore) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(spacingBefore), layoutable, layoutSpecClass);
    } else if (layoutable.spacingAfter != defaultLayoutOptions.spacingAfter) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(spacingAfter), layoutable, layoutSpecClass);
    } else if (layoutable.flexGrow != defaultLayoutOptions.flexGrow) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(flexGrow), layoutable, layoutSpecClass);
    } else if (layoutable.flexShrink != defaultLayoutOptions.flexShrink) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(flexShrink), layoutable, layoutSpecClass);
    } else if (ASRelativeDimensionEqualToRelativeDimension(layoutable.flexBasis, defaultLayoutOptions.flexBasis) == NO) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(flexBasis), layoutable, layoutSpecClass);
    } else if (layoutable.alignSelf != defaultLayoutOptions.alignSelf) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(alignSelf), layoutable, layoutSpecClass);
    }
    
    if (errorMessage != nil) {
      if (error != nil) {
        *error = ASLayoutableValidationErrorForMessage(errorMessage);
      }
      return NO;
    }
    
    return YES;
  };
}

ASLayoutableValidationBlock ASLayoutableValidatorBlockRejectStaticLayoutable()
{
  return ^(id<ASLayoutable> layoutable, NSError * __autoreleasing *error) {
    ASEnvironmentLayoutOptionsState defaultLayoutOptions = ASEnvironmentLayoutOptionsStateMakeDefault();
    
    // Check for default sizeRange and layoutPosition
    ASRelativeSizeRange sizeRange = layoutable.sizeRange;
    
    // Currently setting the preferredFrameSize also updates the sizeRange. Create a size range based on the
    // preferredFrameSize and check it if it's the same as the current sizeRange to be sure it was not changed manually
    CGSize preferredFrameSize = CGSizeZero;
    if ([layoutable respondsToSelector:@selector(preferredFrameSize)]) {
      preferredFrameSize = [(ASDisplayNode *)layoutable preferredFrameSize];
    }
    ASRelativeSizeRange preferredFrameSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(preferredFrameSize);
    
    Class layoutSpecClass = [ASStaticLayoutSpec class];
    NSString *errorMessage = nil;
    if (ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, defaultLayoutOptions.sizeRange) == NO &&
        ASRelativeSizeRangeEqualToRelativeSizeRange(sizeRange, preferredFrameSizeRange) == NO) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(sizeRange), layoutable, layoutSpecClass);
    } else if (!CGPointEqualToPoint(layoutable.layoutPosition, defaultLayoutOptions.layoutPosition)) {
      errorMessage = ASLayoutValidationWrappingErrorMessage(@selector(layoutPosition), layoutable, layoutSpecClass);
    }
    
    if (errorMessage != nil) {
      if (error != nil) {
        *error = ASLayoutableValidationErrorForMessage(errorMessage);
      }
      return NO;
    }
    
    return YES;
  };
}
