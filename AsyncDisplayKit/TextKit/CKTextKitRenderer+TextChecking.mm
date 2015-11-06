/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "CKTextKitRenderer+TextChecking.h"

#import "CKTextKitAttributes.h"
#import "CKTextKitEntityAttribute.h"
#import "CKTextKitRenderer+Positioning.h"
#import "CKTextKitTailTruncater.h"

@implementation CKTextKitTextCheckingResult

{
  // Be explicit about the fact that we are overriding the super class' implementation of -range and -resultType
  // and substituting our own custom values. (We could use @synthesize to make these ivars, but our linter correctly
  // complains; it's weird to use @synthesize for properties that are redeclared on top of an original declaration in
  // the superclass. We only do it here because NSTextCheckingResult doesn't expose an initializer, which is silly.)
  NSRange _rangeOverride;
  NSTextCheckingType _resultTypeOverride;
}

- (instancetype)initWithType:(NSTextCheckingType)type
             entityAttribute:(CKTextKitEntityAttribute *)entityAttribute
                       range:(NSRange)range
{
  if ((self = [super init])) {
    _resultTypeOverride = type;
    _rangeOverride = range;
    _entityAttribute = entityAttribute;
  }
  return self;
}

- (NSTextCheckingType)resultType
{
  return _resultTypeOverride;
}

- (NSRange)range
{
  return _rangeOverride;
}

@end

@implementation CKTextKitRenderer (TextChecking)

- (NSTextCheckingResult *)textCheckingResultAtPoint:(CGPoint)point
{
  __block NSTextCheckingResult *result = nil;
  NSAttributedString *attributedString = self.attributes.attributedString;
  NSAttributedString *truncationAttributedString = self.attributes.truncationAttributedString;

  // get the index of the last character, so we can handle text in the truncation token
  NSRange visibleRange = self.truncater.visibleRanges[0];
  __block NSRange truncationTokenRange = { NSNotFound, 0 };

  [truncationAttributedString enumerateAttribute:CKTextKitTruncationAttributeName inRange:NSMakeRange(0, truncationAttributedString.length)
                                         options:0
                                      usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (value != nil && range.length > 0) {
      truncationTokenRange = range;
    }
  }];

  if (truncationTokenRange.location == NSNotFound) {
    // The truncation string didn't specify a substring which should be highlighted, so we just highlight it all
    truncationTokenRange = { 0, self.attributes.truncationAttributedString.length };
  }

  truncationTokenRange.location += NSMaxRange(visibleRange);

  [self enumerateTextIndexesAtPosition:point usingBlock:^(NSUInteger index, CGRect glyphBoundingRect, BOOL *stop){
    if (index >= truncationTokenRange.location) {
      result = [[CKTextKitTextCheckingResult alloc] initWithType:CKTextKitTextCheckingTypeTruncation
                                                 entityAttribute:nil
                                                           range:truncationTokenRange];
    } else {
      NSRange range;
      NSDictionary *attributes = [attributedString attributesAtIndex:index effectiveRange:&range];
      CKTextKitEntityAttribute *entityAttribute = attributes[CKTextKitEntityAttributeName];
      if (entityAttribute) {
        result = [[CKTextKitTextCheckingResult alloc] initWithType:CKTextKitTextCheckingTypeEntity
                                                   entityAttribute:entityAttribute
                                                             range:range];
      }
    }
    if (result != nil) {
      *stop = YES;
    }
  }];
  return result;
}

@end
