//
//  ASButtonNodeTests.m
//  AsyncDisplayKit
//
//  Created by Luke Parham on 12/3/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ASButtonNode.h"
#import "UIImage+ASConvenience.h"

@interface ASButtonNodeTests : XCTestCase

@end

@implementation ASButtonNodeTests

- (void)testButtonsSetTintColorImageModificationBlockWhenButtonTintColorChanges {
  ASButtonNode *buttonNode = [[ASButtonNode alloc] init];
  [buttonNode setImage:[UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor clearColor] fillColor:[UIColor blueColor]] forState:ASControlStateNormal];
  
  buttonNode.tintColor = [UIColor greenColor];
  
  XCTAssertNotNil(buttonNode.imageNode.imageModificationBlock);
}

- (void)testSettingTintColorBeforeImageHasBeenSetCachesTintColorAndAppliesLater {
  ASButtonNode *buttonNode = [[ASButtonNode alloc] init];
  buttonNode.tintColor = [UIColor greenColor];

  UIImage *testImage = [[UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor clearColor] fillColor:[UIColor blueColor]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [buttonNode setImage:testImage forState:ASControlStateNormal];
  
  XCTAssertNotNil(buttonNode.imageNode.imageModificationBlock);
}

- (void)testButtonWithTintColorButNoTemplateImageShouldNotModifyProvidedImage
{
  ASButtonNode *buttonNode = [[ASButtonNode alloc] init];
  buttonNode.tintColor = [UIColor greenColor];
  
  UIImage *testImage = [UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor clearColor] fillColor:[UIColor blueColor]];
  [buttonNode setImage:testImage forState:ASControlStateNormal];
  
  XCTAssertNil(buttonNode.imageNode.imageModificationBlock);
}

- (void)testButtonWithTemplateImageDoesNotAffectOtherStates
{
  ASButtonNode *buttonNode = [[ASButtonNode alloc] init];
  buttonNode.tintColor = [UIColor greenColor];
  
  UIImage *image = [UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor clearColor] fillColor:[UIColor blueColor]];
  UIImage *templateImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  
  [buttonNode setImage:templateImage forState:ASControlStateNormal];
  [buttonNode setImage:image forState:ASControlStateSelected];
  
  buttonNode.selected = YES;
  
  XCTAssertNil(buttonNode.imageNode.imageModificationBlock);
}

- (void)testTintColorIsSetOnSuperClass
{
  ASButtonNode *buttonNode = [[ASButtonNode alloc] init];
  buttonNode.tintColor = [UIColor greenColor];

  XCTAssert([buttonNode.tintColor isEqual:[UIColor greenColor]]);
}

@end
