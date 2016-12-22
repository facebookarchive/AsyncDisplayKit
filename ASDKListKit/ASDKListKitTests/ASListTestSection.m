//
//  ASListTestSection.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASListTestSection.h"
#import "ASListTestCellNode.h"

@implementation ASListTestSection

- (instancetype)init {
  if (self = [super init]) {
    _selectedItemIndex = NSNotFound;
  }
  return self;
}

- (NSInteger)numberOfItems {
  return self.itemCount;
}

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd));
  return CGSizeMake(100, 10);
}

ASIGSectionControllerCellForIndexImplementation

- (void)didUpdateToObject:(id)object {
  if ([object isKindOfClass:[NSNumber class]]) {
    self.itemCount = [object integerValue];
  }
}

- (void)didSelectItemAtIndex:(NSInteger)index {
  self.selectedItemIndex = index;
}

- (ASCellNodeBlock)nodeBlockForItemAtIndex:(NSInteger)index
{
  return ^{
    ASListTestCellNode *node = [[ASListTestCellNode alloc] init];
    node.style.preferredSize = CGSizeMake(100, 10);
    return node;
  };
}

@end
