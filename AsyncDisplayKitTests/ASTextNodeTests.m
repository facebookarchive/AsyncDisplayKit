/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <CoreText/CoreText.h>

#import <OCMock/OCMock.h>

#import <AsyncDisplayKit/ASTextNode.h>

#import <XCTest/XCTest.h>

@interface ASTextNodeTestDelegate : NSObject <ASTextNodeDelegate>

@property (nonatomic, copy, readonly) NSString *tappedLinkAttribute;
@property (nonatomic, assign, readonly) id tappedLinkValue;


@end

@implementation ASTextNodeTestDelegate

- (void)textNode:(ASTextNode *)textNode tappedLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point textRange:(NSRange)textRange
{
  _tappedLinkAttribute = attribute;
  _tappedLinkValue = value;
}

- (BOOL)textNode:(ASTextNode *)textNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point
{
  return YES;
}

@end

@interface ASTextNodeTests : XCTestCase

@property (nonatomic, readwrite, strong) ASTextNode *textNode;
@property (nonatomic, readwrite, copy) NSAttributedString *attributedString;

@end

@implementation ASTextNodeTests

- (void)setUp
{
  [super setUp];
  _textNode = [[ASTextNode alloc] init];

  UIFontDescriptor *desc =
  [UIFontDescriptor fontDescriptorWithName:@"Didot" size:18];
  NSArray *arr =
  @[@{UIFontFeatureTypeIdentifierKey:@(kLetterCaseType),
      UIFontFeatureSelectorIdentifierKey:@(kSmallCapsSelector)}];
  desc =
  [desc fontDescriptorByAddingAttributes:
   @{UIFontDescriptorFeatureSettingsAttribute:arr}];
  UIFont *f = [UIFont fontWithDescriptor:desc size:0];
  NSDictionary *d = @{NSFontAttributeName: f};
  NSMutableAttributedString *mas =
  [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." attributes:d];
  NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
  para.alignment = NSTextAlignmentCenter;
  [mas addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0,mas.length)];
  _attributedString = mas;
  _textNode.attributedString = _attributedString;
}

#pragma mark - ASTextNode

- (void)testAllocASTextNode
{
  ASTextNode *node = [[ASTextNode alloc] init];
  XCTAssertTrue([[node class] isSubclassOfClass:[ASTextNode class]], @"ASTextNode alloc should return an instance of ASTextNode, instead returned %@", [node class]);
}

#pragma mark - ASTextNode

- (void)testSettingTruncationMessage
{
  NSAttributedString *truncation = [[NSAttributedString alloc] initWithString:@"..." attributes:nil];
  _textNode.truncationAttributedString = truncation;
  XCTAssertTrue([_textNode.truncationAttributedString isEqualToAttributedString:truncation], @"Failed to set truncation message");
}

- (void)testCalculatedSizeIsGreaterThanOrEqualToConstrainedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_textNode measure:constrainedSize];
    XCTAssertTrue(calculatedSize.width <= constrainedSize.width, @"Calculated width (%f) should be less than or equal to constrained width (%f)", calculatedSize.width, constrainedSize.width);
    XCTAssertTrue(calculatedSize.height <= constrainedSize.height, @"Calculated height (%f) should be less than or equal to constrained height (%f)", calculatedSize.height, constrainedSize.height);
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_textNode measure:constrainedSize];
    CGSize recalculatedSize = [_textNode measure:calculatedSize];

    XCTAssertTrue(CGSizeEqualToSize(calculatedSize, recalculatedSize), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedFloatingPointSize
{
  for (CGFloat i = 10; i < 500; i *= 1.3) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_textNode measure:constrainedSize];
    CGSize recalculatedSize = [_textNode measure:calculatedSize];

    XCTAssertTrue(CGSizeEqualToSize(calculatedSize, recalculatedSize), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

- (void)testAccessibility
{
  _textNode.attributedString = _attributedString;
  XCTAssertTrue(_textNode.isAccessibilityElement, @"Should be an accessibility element");
  XCTAssertTrue(_textNode.accessibilityTraits == UIAccessibilityTraitStaticText, @"Should have static text accessibility trait, instead has %llu", _textNode.accessibilityTraits);

  XCTAssertTrue([_textNode.accessibilityLabel isEqualToString:_attributedString.string], @"Accessibility label is incorrectly set to \n%@\n when it should be \n%@\n", _textNode.accessibilityLabel, _attributedString.string);
}

- (void)testLinkAttribute
{
  NSString *linkAttributeName = @"MockLinkAttributeName";
  NSString *linkAttributeValue = @"MockLinkAttributeValue";
  NSString *linkString = @"Link";
  NSRange linkRange = NSMakeRange(0, linkString.length);
  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:linkString attributes:@{ linkAttributeName : linkAttributeValue}];
  _textNode.attributedString = attributedString;
  _textNode.linkAttributeNames = @[linkAttributeName];

  ASTextNodeTestDelegate *delegate = [ASTextNodeTestDelegate new];
  _textNode.delegate = delegate;

  [_textNode measure:CGSizeMake(100, 100)];
  NSRange returnedLinkRange;
  NSString *returnedAttributeName;
  NSString *returnedLinkAttributeValue = [_textNode linkAttributeValueAtPoint:CGPointMake(3, 3) attributeName:&returnedAttributeName range:&returnedLinkRange];
  XCTAssertTrue([linkAttributeName isEqualToString:returnedAttributeName], @"Expecting a link attribute name of %@, returned %@", linkAttributeName, returnedAttributeName);
  XCTAssertTrue([linkAttributeValue isEqualToString:returnedLinkAttributeValue], @"Expecting a link attribute value of %@, returned %@", linkAttributeValue, returnedLinkAttributeValue);
  XCTAssertTrue(NSEqualRanges(linkRange, returnedLinkRange), @"Expected a range of %@, got a link range of %@", NSStringFromRange(linkRange), NSStringFromRange(returnedLinkRange));
}

- (void)testTapNotOnALinkAttribute
{
  NSString *linkAttributeName = @"MockLinkAttributeName";
  NSString *linkAttributeValue = @"MockLinkAttributeValue";
  NSString *linkString = @"Link notalink";
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:linkString];
  [attributedString addAttribute:linkAttributeName value:linkAttributeValue range:NSMakeRange(0, 4)];
  _textNode.attributedString = attributedString;
  _textNode.linkAttributeNames = @[linkAttributeName];

  ASTextNodeTestDelegate *delegate = [ASTextNodeTestDelegate new];
  _textNode.delegate = delegate;

  CGSize calculatedSize = [_textNode measure:CGSizeMake(100, 100)];
  NSRange returnedLinkRange = NSMakeRange(NSNotFound, 0);
  NSRange expectedRange = NSMakeRange(NSNotFound, 0);
  NSString *returnedAttributeName;
  CGPoint pointNearEndOfString = CGPointMake(calculatedSize.width - 3, calculatedSize.height / 2);
  NSString *returnedLinkAttributeValue = [_textNode linkAttributeValueAtPoint:pointNearEndOfString attributeName:&returnedAttributeName range:&returnedLinkRange];
  XCTAssertFalse(returnedAttributeName, @"Expecting no link attribute name, returned %@", returnedAttributeName);
  XCTAssertFalse(returnedLinkAttributeValue, @"Expecting no link attribute value, returned %@", returnedLinkAttributeValue);
  XCTAssertTrue(NSEqualRanges(expectedRange, returnedLinkRange), @"Expected a range of %@, got a link range of %@", NSStringFromRange(expectedRange), NSStringFromRange(returnedLinkRange));

  XCTAssertFalse(delegate.tappedLinkAttribute, @"Expected the delegate to be told that %@ was tapped, instead it thinks the tapped attribute is %@", linkAttributeName, delegate.tappedLinkAttribute);
  XCTAssertFalse(delegate.tappedLinkValue, @"Expected the delegate to be told that the value %@ was tapped, instead it thinks the tapped attribute value is %@", linkAttributeValue, delegate.tappedLinkValue);
}

#pragma mark exclusion Paths

- (void)testSettingExclusionPaths
{
  NSArray *exclusionPaths = @[[UIBezierPath bezierPathWithRect:CGRectMake(10, 20, 30, 40)]];
  _textNode.exclusionPaths = exclusionPaths;
  XCTAssertTrue([_textNode.exclusionPaths isEqualToArray:exclusionPaths], @"Failed to set exclusion paths");
}

- (void)testAddingExclusionPathsShouldInvalidateAndIncreaseTheSize
{
  CGSize constrainedSize = CGSizeMake(100, CGFLOAT_MAX);
  CGSize sizeWithoutExclusionPaths = [_textNode measure:constrainedSize];
  _textNode.exclusionPaths = @[[UIBezierPath bezierPathWithRect:CGRectMake(50, 20, 30, 40)]];
  CGSize sizeWithExclusionPaths = [_textNode measure:constrainedSize];

  XCTAssertGreaterThan(sizeWithExclusionPaths.height, sizeWithoutExclusionPaths.height, @"Setting exclusions paths should invalidate the calculated size and return a greater size");
}

@end
