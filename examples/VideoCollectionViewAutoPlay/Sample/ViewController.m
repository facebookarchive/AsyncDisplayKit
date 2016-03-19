//
//  ViewController.m
//  Sample
//
//  Created by Erekle on 3/14/16.
//  Copyright © 2016 facebook. All rights reserved.
//

#import "ViewController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "VideoCellNode.h"

@interface ViewController () <ASCollectionDataSource,ASCollectionDelegate>{
  ASCollectionView *_collectionView;
}
@end

@implementation ViewController

- (instancetype)init{
  self = [super init];
  if(self){
    [self privateInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
  self = [super initWithCoder:aDecoder];
  if(self){
    [self privateInit];
  }
  return self;
}

- (void)privateInit{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.minimumLineSpacing = 0.0;
  _collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  _collectionView.asyncDataSource = self;
  _collectionView.asyncDelegate = self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self.view addSubview:_collectionView];
  [_collectionView reloadDataWithCompletion:nil];
}

- (void)viewWillLayoutSubviews{
//  [super viewWillLayoutSubviews];
  _collectionView.frame = self.view.bounds;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

#pragma mark - ASCollectionView
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  VideoCellNode *node = [[VideoCellNode alloc] init];
  return node;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return 50;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath{
  CGFloat width = self.view.bounds.size.width;
  CGFloat minHeight = self.view.bounds.size.width / 1.777;
  CGFloat maxHeight = CGFLOAT_MAX;
  return ASSizeRangeMake(CGSizeMake(width, minHeight), CGSizeMake(width, maxHeight));
}

@end
