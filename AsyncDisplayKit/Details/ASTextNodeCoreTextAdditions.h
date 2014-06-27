/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

ASDISPLAYNODE_EXTERN_C_BEGIN
/**
 @abstract Returns whether a given attribute is an unsupported Core Text attribute.
 @param attributeName The name of the attribute
 @discussion The following Core Text attributes are not supported on NSAttributedString, and thus will not be preserved during the conversion:
              - kCTForegroundColorFromContextAttributeName
              - kCTSuperscriptAttributeName
              - kCTGlyphInfoAttributeName
              - kCTCharacterShapeAttributeName
              - kCTLanguageAttributeName
              - kCTRunDelegateAttributeName
              - kCTBaselineClassAttributeName
              - kCTBaselineInfoAttributeName
              - kCTBaselineReferenceInfoAttributeName
              - kCTWritingDirectionAttributeName
              - kCTUnderlineColorAttributeName
 @result Whether attributeName is an unsupported Core Text attribute.
 */
BOOL ASAttributeWithNameIsUnsupportedCoreTextAttribute(NSString *attributeName);


/**
 @abstract Returns an attributes dictionary for use by NSAttributedString, given a dictionary of Core Text attributes.
 @param coreTextAttributes An NSDictionary whose keys are CFAttributedStringRef attributes.
 @discussion The following Core Text attributes are not supported on NSAttributedString, and thus will not be preserved during the conversion:
              - kCTForegroundColorFromContextAttributeName
              - kCTSuperscriptAttributeName
              - kCTGlyphInfoAttributeName
              - kCTCharacterShapeAttributeName
              - kCTLanguageAttributeName
              - kCTRunDelegateAttributeName
              - kCTBaselineClassAttributeName
              - kCTBaselineInfoAttributeName
              - kCTBaselineReferenceInfoAttributeName
              - kCTWritingDirectionAttributeName
              - kCTUnderlineColorAttributeName
 @result An NSDictionary of attributes for use by NSAttributedString.
 */
extern NSDictionary *NSAttributedStringAttributesForCoreTextAttributes(NSDictionary *coreTextAttributes);

/**
  @abstract Returns an NSAttributedString whose Core Text attributes have been converted, where possible, to NSAttributedString attributes.
  @param dirtyAttributedString An NSAttributedString that may contain Core Text attributes.
  @result An NSAttributedString that's preserved as many CFAttributedString attributes as possible.
 */
extern NSAttributedString *ASCleanseAttributedStringOfCoreTextAttributes(NSAttributedString *dirtyAttributedString);

ASDISPLAYNODE_EXTERN_C_END

#pragma mark -
#pragma mark -
@interface NSParagraphStyle (ASTextNodeCoreTextAdditions)

/**
  @abstract Returns an NSParagraphStyle initialized with the paragraph specifiers from the given CTParagraphStyleRef.
  @param coreTextParagraphStyle A Core Text paragraph style.
  @discussion It is important to note that not all CTParagraphStyle specifiers are supported by NSParagraphStyle, and consequently, this is a lossy conversion. Notably, the following specifiers will not preserved:
        - kCTParagraphStyleSpecifierTabStops
        - kCTParagraphStyleSpecifierDefaultTabInterval
        - kCTParagraphStyleSpecifierMaximumLineSpacing
        - kCTParagraphStyleSpecifierMinimumLineSpacing
        - kCTParagraphStyleSpecifierLineSpacingAdjustment
        - kCTParagraphStyleSpecifierLineBoundsOptions
  @result An NSParagraphStyle initializd with as many of the paragraph specifiers from `coreTextParagraphStyle` as possible.

 */
+ (instancetype)paragraphStyleWithCTParagraphStyle:(CTParagraphStyleRef)coreTextParagraphStyle;

@end
