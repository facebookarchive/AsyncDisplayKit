//
//  IGListAdapter+AsyncDisplayKit.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_IG_LIST_KIT

#import "IGListAdapter+AsyncDisplayKit.h"
#import "ASIGListAdapterBasedDataSource.h"
#import "ASAssert.h"
#import <objc/runtime.h>

@implementation IGListAdapter (AsyncDisplayKit)

- (void)setASDKCollectionNode:(ASCollectionNode *)collectionNode
{
  ASDisplayNodeAssertMainThread();

  // Attempt to retrieve previous data source.
  ASIGListAdapterBasedDataSource *dataSource = objc_getAssociatedObject(self, _cmd);
  // Bomb if we already made one.
  if (dataSource != nil) {
    ASDisplayNodeFailAssert(@"Attempt to call %@ multiple times on the same list adapter. Not currently allowed!", NSStringFromSelector(_cmd));
    return;
  }

  // Make a data source and retain it.
  dataSource = [[ASIGListAdapterBasedDataSource alloc] initWithListAdapter:self];
  objc_setAssociatedObject(self, _cmd, dataSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  // Attach the data source to the collection node.
  collectionNode.dataSource = dataSource;
  collectionNode.delegate = dataSource;
  __weak IGListAdapter *weakSelf = self;
  [collectionNode onDidLoad:^(__kindof ASCollectionNode * _Nonnull collectionNode) {
#if IG_LIST_COLLECTION_VIEW
    // We manually set the superclass of ASCollectionView to IGListCollectionView at runtime if needed.
    weakSelf.collectionView = (IGListCollectionView *)collectionNode.view;
#else
    weakSelf.collectionView = collectionNode.view;
#endif
  }];
}

@end

#endif // AS_IG_LIST_KIT
