//
//  ASListTestSupplementarySource.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASListTestSupplementarySource.h"
#import "ASListTestSupplementaryNode.h"

@implementation ASListTestSupplementarySource

ASIGSupplementarySourceViewForSupplementaryElementImplementation(self.sectionController)
ASIGSupplementarySourceSizeForSupplementaryElementImplementation

- (ASCellNode *)nodeForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  ASListTestSupplementaryNode *node = [[ASListTestSupplementaryNode alloc] init];
  node.style.preferredSize = CGSizeMake(100, 10);
  return node;
}

@end
