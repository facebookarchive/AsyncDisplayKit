//
//  ASListAdapterImpl.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import "ASListAdapterImpl.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <objc/runtime.h>

@interface ASListAdapterImpl ()
@property (nonatomic, weak, readonly) IGListAdapter *listAdapter;
@end

@implementation ASListAdapterImpl
@synthesize collectionNode = _collectionNode;

- (instancetype)initWithListAdapter:(IGListAdapter *)listAdapter
{
  if (self = [super init]) {
    [ASListAdapterImpl setASCollectionViewSuperclass];
    [ASListAdapterImpl configureUpdater:listAdapter.updater];

    _listAdapter = listAdapter;
  }
  return self;
}

#pragma mark - ASListAdapter

- (void)setCollectionNode:(ASCollectionNode *)collectionNode
{
  _collectionNode = collectionNode;
  __weak IGListAdapter *listAdapter = _listAdapter;
  [collectionNode onDidLoad:^(ASCollectionNode * _Nonnull collectionNode) {
    listAdapter.collectionView = (IGListCollectionView *)collectionNode.view;
  }];
}

- (id<ASSectionController>)sectionControllerForSection:(NSInteger)section
{
  IGListAdapter *listAdapter = _listAdapter;
  id object = [listAdapter objectAtSection:section];
  id<ASSectionController> ctrl = [listAdapter sectionControllerForObject:object];
  ASDisplayNodeAssert([ctrl conformsToProtocol:@protocol(ASSectionController)], @"Expected section controller to conform to %@. Controller: %@", NSStringFromProtocol(@protocol(ASSectionController)), ctrl);
  return ctrl;
}

#pragma mark - Helpers

/**
 * Set ASCollectionView's superclass to IGListCollectionView.
 * Scary! If IGListKit removed the subclassing restriction, we could
 * use #if in the @interface to choose the superclass based on
 * whether we have IGListKit available.
 */
+ (void)setASCollectionViewSuperclass
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    class_setSuperclass([self class], [IGListCollectionView class]);
  });
#pragma clang diagnostic pop
}

/// Ensure updater won't call reloadData on us.
+ (void)configureUpdater:(id<IGListUpdatingDelegate>)updater
{
  // Cast to NSObject will be removed after https://github.com/Instagram/IGListKit/pull/435
  if ([(id<NSObject>)updater isKindOfClass:[IGListAdapterUpdater class]]) {
    [(IGListAdapterUpdater *)updater setAllowsBackgroundReloading:NO];
  } else {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSLog(@"WARNING: Use of non-%@ updater with AsyncDisplayKit is discouraged. Updater: %@", NSStringFromClass([IGListAdapterUpdater class]), updater);
    });
  }
}

@end

#endif // IG_LIST_KIT
