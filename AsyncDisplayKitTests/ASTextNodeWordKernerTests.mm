/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASTextNodeTextKitHelpers.h"
#import "ASTextNodeTypes.h"
#import "ASTextNodeWordKerner.h"

#pragma mark - Tests

@interface ASTextNodeWordKernerTests : XCTestCase

@property (nonatomic, readwrite, strong) ASTextNodeWordKerner *layoutManagerDelegate;
@property (nonatomic, readwrite, strong) ASTextKitComponents *components;
@property (nonatomic, readwrite, copy) NSAttributedString *attributedString;

@end

@implementation ASTextNodeWordKernerTests

- (void)setUp
{
  [super setUp];
  _layoutManagerDelegate = [[ASTextNodeWordKerner alloc] init];
  _components.layoutManager.delegate = _layoutManagerDelegate;
}

- (void)setupTextKitComponentsWithoutWordKerning
{
  CGSize size = CGSizeMake(200, 200);
  NSDictionary *attributes = nil;
  NSString *seedString = @"Hello world";
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:seedString attributes:attributes];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];
}

- (void)setupTextKitComponentsWithWordKerning
{
  CGSize size = CGSizeMake(200, 200);
  NSDictionary *attributes = @{ASTextNodeWordKerningAttributeName: @".5"};
  NSString *seedString = @"Hello world";
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:seedString attributes:attributes];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];
}

- (void)setupTextKitComponentsWithWordKerningDifferentFontSizes
{
  CGSize size = CGSizeMake(200, 200);
  NSDictionary *attributes = @{ASTextNodeWordKerningAttributeName: @".5"};
  NSString *seedString = @"  ";
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:seedString attributes:attributes];
  UIFont *bigFont = [UIFont systemFontOfSize:36];
  UIFont *normalFont = [UIFont systemFontOfSize:12];
  [attributedString addAttribute:NSFontAttributeName value:bigFont range:NSMakeRange(0, 1)];
  [attributedString addAttribute:NSFontAttributeName value:normalFont range:NSMakeRange(1, 1)];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];
}

- (void)testSomeGlyphsToChangeIfWordKerning
{
  [self setupTextKitComponentsWithWordKerning];

  NSInteger glyphsToChange = [self _layoutManagerShouldGenerateGlyphs];
  XCTAssertTrue(glyphsToChange > 0, @"Should have changed the properties on some glyphs");
}

- (void)testSpaceBoundingBoxForNoWordKerning
{
  CGSize size = CGSizeMake(200, 200);
  UIFont *font = [UIFont systemFontOfSize:12.0];
  NSDictionary *attributes = @{NSFontAttributeName : font};
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@" " attributes:attributes];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];
  CGFloat expectedWidth = [@" " sizeWithAttributes:@{ NSFontAttributeName : font }].width;

  CGRect boundingBox = [_layoutManagerDelegate layoutManager:_components.layoutManager boundingBoxForControlGlyphAtIndex:0 forTextContainer:_components.textContainer proposedLineFragment:CGRectZero glyphPosition:CGPointZero characterIndex:0];
    
  XCTAssertEqualWithAccuracy(boundingBox.size.width, expectedWidth, FLT_EPSILON, @"Word kerning shouldn't alter the default width of %f. Encountered space width was %f", expectedWidth, boundingBox.size.width);
}

- (void)testSpaceBoundingBoxForWordKerning
{
  CGSize size = CGSizeMake(200, 200);
  UIFont *font = [UIFont systemFontOfSize:12];

  CGFloat kernValue = 0.5;
  NSDictionary *attributes = @{ASTextNodeWordKerningAttributeName: @(kernValue),
                               NSFontAttributeName : font};
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@" " attributes:attributes];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];
  CGFloat expectedWidth = [@" " sizeWithAttributes:@{ NSFontAttributeName : font }].width + kernValue;

  CGRect boundingBox = [_layoutManagerDelegate layoutManager:_components.layoutManager boundingBoxForControlGlyphAtIndex:0 forTextContainer:_components.textContainer proposedLineFragment:CGRectZero glyphPosition:CGPointZero characterIndex:0];
  XCTAssertEqualWithAccuracy(boundingBox.size.width, expectedWidth, FLT_EPSILON, @"Word kerning shouldn't alter the default width of %f. Encountered space width was %f", expectedWidth, boundingBox.size.width);
}

- (NSInteger)_layoutManagerShouldGenerateGlyphs
{
  NSRange stringRange = NSMakeRange(0, _components.textStorage.length);
  NSRange glyphRange = [_components.layoutManager glyphRangeForCharacterRange:stringRange actualCharacterRange:NULL];
  NSInteger glyphCount = glyphRange.length;
  NSUInteger *characterIndexes = (NSUInteger *)malloc(sizeof(NSUInteger) * glyphCount);
  for (NSUInteger i=0; i < stringRange.length; i++) {
    characterIndexes[i] = i;
  }
  NSGlyphProperty *glyphProperties = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphCount);
  CGGlyph *glyphs = (CGGlyph *)malloc(sizeof(CGGlyph) * glyphCount);
  NSInteger glyphsToChange = [_layoutManagerDelegate layoutManager:_components.layoutManager shouldGenerateGlyphs:glyphs properties:glyphProperties characterIndexes:characterIndexes font:NULL forGlyphRange:stringRange];
  free(characterIndexes);
  free(glyphProperties);
  free(glyphs);
  return glyphsToChange;
}

- (void)testPerCharacterWordKerning
{
  [self setupTextKitComponentsWithWordKerningDifferentFontSizes];
  CGPoint glyphPosition = CGPointZero;
  NSUInteger bigSpaceIndex = 0;
  NSUInteger normalSpaceIndex = 1;
  CGRect bigBoundingBox = [_layoutManagerDelegate layoutManager:_components.layoutManager boundingBoxForControlGlyphAtIndex:bigSpaceIndex forTextContainer:_components.textContainer proposedLineFragment:CGRectZero glyphPosition:glyphPosition characterIndex:bigSpaceIndex];
  CGRect normalBoundingBox = [_layoutManagerDelegate layoutManager:_components.layoutManager boundingBoxForControlGlyphAtIndex:normalSpaceIndex forTextContainer:_components.textContainer proposedLineFragment:CGRectZero glyphPosition:glyphPosition characterIndex:normalSpaceIndex];
  XCTAssertTrue(bigBoundingBox.size.width > normalBoundingBox.size.width, @"Unbolded and bolded spaces should have different kerning");
}

- (void)testWordKerningDoesNotAlterGlyphOrigin
{
  CGSize size = CGSizeMake(200, 200);
  NSDictionary *attributes = @{ASTextNodeWordKerningAttributeName: @".5"};
  NSString *seedString = @" ";
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:seedString attributes:attributes];
  UIFont *normalFont = [UIFont systemFontOfSize:12];
  [attributedString addAttribute:NSFontAttributeName value:normalFont range:NSMakeRange(0, 1)];
  _components = [ASTextKitComponents componentsWithAttributedSeedString:attributedString textContainerSize:size];

  CGPoint glyphPosition = CGPointMake(42, 54);

  CGRect boundingBox = [_layoutManagerDelegate layoutManager:_components.layoutManager boundingBoxForControlGlyphAtIndex:0 forTextContainer:_components.textContainer proposedLineFragment:CGRectZero glyphPosition:glyphPosition characterIndex:0];
  XCTAssertTrue(CGPointEqualToPoint(glyphPosition, boundingBox.origin), @"Word kerning shouldn't alter the origin point of a glyph");
}

@end
