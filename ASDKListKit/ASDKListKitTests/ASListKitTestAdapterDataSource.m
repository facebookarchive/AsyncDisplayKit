//
//  ASListKitTestAdapterDataSource.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASListKitTestAdapterDataSource.h"
#import "ASListTestSection.h"

@implementation ASListKitTestAdapterDataSource

- (NSArray *)objectsForListAdapter:(IGListAdapter *)listAdapter {
  return self.objects;
}

- (IGListSectionController <IGListSectionType> *)listAdapter:(IGListAdapter *)listAdapter sectionControllerForObject:(id)object {
  ASListTestSection *section = [[ASListTestSection alloc] init];
  return section;
}

- (nullable UIView *)emptyViewForListAdapter:(IGListAdapter *)listAdapter {
  return nil;
}

@end
