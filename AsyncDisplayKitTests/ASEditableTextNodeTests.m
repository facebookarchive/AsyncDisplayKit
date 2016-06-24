//
//  ASEditableTextNodeTests.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 5/31/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASEditableTextNode.h>

static BOOL CGSizeEqualToSizeWithIn(CGSize size1, CGSize size2, CGFloat delta)
{
  return fabs(size1.width - size2.width) < delta && fabs(size1.height - size2.height) < delta;
}

@interface ASEditableTextNodeTests : XCTestCase
@property (nonatomic, readwrite, strong) ASEditableTextNode *editableTextNode;
@property (nonatomic, readwrite, copy) NSAttributedString *attributedText;
@end

@implementation ASEditableTextNodeTests

- (void)setUp
{
  [super setUp];
  
  _editableTextNode = [[ASEditableTextNode alloc] init];
  
  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."];
  NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
  para.alignment = NSTextAlignmentCenter;
  para.lineSpacing = 1.0;
  [mas addAttribute:NSParagraphStyleAttributeName value:para
              range:NSMakeRange(0, mas.length - 1)];
  
  // Vary the linespacing on the last line
  NSMutableParagraphStyle *lastLinePara = [NSMutableParagraphStyle new];
  lastLinePara.alignment = para.alignment;
  lastLinePara.lineSpacing = 5.0;
  [mas addAttribute:NSParagraphStyleAttributeName value:lastLinePara
              range:NSMakeRange(mas.length - 1, 1)];
  
  _attributedText = mas;
  _editableTextNode.attributedText = _attributedText;
}

#pragma mark - ASEditableTextNode

- (void)testAllocASEditableTextNode
{
  ASEditableTextNode *node = [[ASEditableTextNode alloc] init];
  XCTAssertTrue([[node class] isSubclassOfClass:[ASEditableTextNode class]], @"ASTextNode alloc should return an instance of ASTextNode, instead returned %@", [node class]);
}

#pragma mark - ASEditableTextNode Tests

- (void)testUITextInputTraitDefaults
{
  ASEditableTextNode *editableTextNode = [[ASEditableTextNode alloc] init];
  XCTAssertTrue(editableTextNode.textView.autocapitalizationType == UITextAutocapitalizationTypeSentences, @"textView's autocapitalizationType should be UITextAutocapitalizationTypeSentences.");
  XCTAssertTrue(editableTextNode.textView.autocorrectionType == UITextAutocorrectionTypeDefault,           @"textView's autocorrectionType should be UITextAutocorrectionTypeDefault.");
  XCTAssertTrue(editableTextNode.textView.spellCheckingType == UITextSpellCheckingTypeDefault,             @"textView's spellCheckingType should be UITextSpellCheckingTypeDefault.");
  XCTAssertTrue(editableTextNode.textView.keyboardType == UIKeyboardTypeDefault,                           @"textView's keyboardType should be UIKeyboardTypeDefault.");
  XCTAssertTrue(editableTextNode.textView.keyboardAppearance == UIKeyboardAppearanceDefault,               @"textView's keyboardAppearance should be UIKeyboardAppearanceDefault.");
  XCTAssertTrue(editableTextNode.textView.returnKeyType == UIReturnKeyDefault,                             @"textView's returnKeyType should be UIReturnKeyDefault.");
  XCTAssertTrue(editableTextNode.textView.enablesReturnKeyAutomatically == NO,                             @"textView's enablesReturnKeyAutomatically should be enablesReturnKeyAutomatically.");
  XCTAssertTrue(editableTextNode.textView.isSecureTextEntry == NO,                                         @"textView's isSecureTextEntry should be isSecureTextEntry.");
}

- (void)testUITextInputTraitsSetTraitsBeforeViewLoaded
{
  ASEditableTextNode *editableTextNode = [[ASEditableTextNode alloc] init];
  editableTextNode.autocapitalizationType = UITextAutocapitalizationTypeWords;
  editableTextNode.autocorrectionType = UITextAutocorrectionTypeYes;
  editableTextNode.spellCheckingType = UITextSpellCheckingTypeYes;
  editableTextNode.keyboardType = UIKeyboardTypeTwitter;
  editableTextNode.keyboardAppearance = UIKeyboardAppearanceDark;
  editableTextNode.returnKeyType = UIReturnKeyGo;
  editableTextNode.enablesReturnKeyAutomatically = YES;
  editableTextNode.secureTextEntry = YES;
  
  XCTAssertTrue(editableTextNode.textView.autocapitalizationType == UITextAutocapitalizationTypeWords, @"textView's autocapitalizationType should be UITextAutocapitalizationTypeAllCharacters.");
  XCTAssertTrue(editableTextNode.textView.autocorrectionType == UITextAutocorrectionTypeYes,                   @"textView's autocorrectionType should be UITextAutocorrectionTypeYes.");
  XCTAssertTrue(editableTextNode.textView.spellCheckingType == UITextSpellCheckingTypeYes,                     @"textView's spellCheckingType should be UITextSpellCheckingTypeYes.");
  XCTAssertTrue(editableTextNode.textView.keyboardType == UIKeyboardTypeTwitter,                               @"textView's keyboardType should be UIKeyboardTypeTwitter.");
  XCTAssertTrue(editableTextNode.textView.keyboardAppearance == UIKeyboardAppearanceDark,                      @"textView's keyboardAppearance should be UIKeyboardAppearanceDark.");
  XCTAssertTrue(editableTextNode.textView.returnKeyType == UIReturnKeyGo,                                      @"textView's returnKeyType should be UIReturnKeyGo.");
  XCTAssertTrue(editableTextNode.textView.enablesReturnKeyAutomatically == YES,                                @"textView's enablesReturnKeyAutomatically should be enablesReturnKeyAutomatically.");
  XCTAssertTrue(editableTextNode.textView.isSecureTextEntry == YES,                                            @"textView's isSecureTextEntry should be isSecureTextEntry.");
}

- (void)testUITextInputTraitsChangeTraitAfterViewLoaded
{
  ASEditableTextNode *editableTextNode = [[ASEditableTextNode alloc] init];
  editableTextNode.textView.autocapitalizationType = UITextAutocapitalizationTypeWords;
  editableTextNode.textView.autocorrectionType = UITextAutocorrectionTypeYes;
  editableTextNode.textView.spellCheckingType = UITextSpellCheckingTypeYes;
  editableTextNode.textView.keyboardType = UIKeyboardTypeTwitter;
  editableTextNode.textView.keyboardAppearance = UIKeyboardAppearanceDark;
  editableTextNode.textView.returnKeyType = UIReturnKeyGo;
  editableTextNode.textView.enablesReturnKeyAutomatically = YES;
  editableTextNode.textView.secureTextEntry = YES;
  
  XCTAssertTrue(editableTextNode.autocapitalizationType == UITextAutocapitalizationTypeWords, @"textView's autocapitalizationType should be UITextAutocapitalizationTypeAllCharacters.");
  XCTAssertTrue(editableTextNode.autocorrectionType == UITextAutocorrectionTypeYes,                   @"textView's autocorrectionType should be UITextAutocorrectionTypeYes.");
  XCTAssertTrue(editableTextNode.spellCheckingType == UITextSpellCheckingTypeYes,                     @"textView's spellCheckingType should be UITextSpellCheckingTypeYes.");
  XCTAssertTrue(editableTextNode.keyboardType == UIKeyboardTypeTwitter,                               @"textView's keyboardType should be UIKeyboardTypeTwitter.");
  XCTAssertTrue(editableTextNode.keyboardAppearance == UIKeyboardAppearanceDark,                      @"textView's keyboardAppearance should be UIKeyboardAppearanceDark.");
  XCTAssertTrue(editableTextNode.returnKeyType == UIReturnKeyGo,                                      @"textView's returnKeyType should be UIReturnKeyGo.");
  XCTAssertTrue(editableTextNode.enablesReturnKeyAutomatically == YES,                                @"textView's enablesReturnKeyAutomatically should be enablesReturnKeyAutomatically.");
  XCTAssertTrue(editableTextNode.isSecureTextEntry == YES,                                            @"textView's isSecureTextEntry should be isSecureTextEntry.");
}

- (void)testSetPreferredFrameSize
{
  CGSize preferredFrameSize = CGSizeMake(100, 100);
  _editableTextNode.preferredFrameSize = preferredFrameSize;
  
  CGSize calculatedSize = [_editableTextNode measure:CGSizeZero];
  XCTAssertTrue(calculatedSize.width != preferredFrameSize.width, @"Calculated width (%f) should be equal to preferred width (%f)", calculatedSize.width, preferredFrameSize.width);
  XCTAssertTrue(calculatedSize.width != preferredFrameSize.width, @"Calculated height (%f) should be equal to preferred height (%f)", calculatedSize.width, preferredFrameSize.width);
  
  _editableTextNode.preferredFrameSize = CGSizeZero;
}

- (void)testCalculatedSizeIsGreaterThanOrEqualToConstrainedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    XCTAssertTrue(calculatedSize.width <= constrainedSize.width, @"Calculated width (%f) should be less than or equal to constrained width (%f)", calculatedSize.width, constrainedSize.width);
    XCTAssertTrue(calculatedSize.height <= constrainedSize.height, @"Calculated height (%f) should be less than or equal to constrained height (%f)", calculatedSize.height, constrainedSize.height);
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    CGSize recalculatedSize = [_editableTextNode measure:calculatedSize];
    
    XCTAssertTrue(CGSizeEqualToSizeWithIn(calculatedSize, recalculatedSize, 4.0), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedFloatingPointSize
{
  for (CGFloat i = 10; i < 500; i *= 1.3) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    CGSize recalculatedSize = [_editableTextNode measure:calculatedSize];

    XCTAssertTrue(CGSizeEqualToSizeWithIn(calculatedSize, recalculatedSize, 11.0), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

@end
