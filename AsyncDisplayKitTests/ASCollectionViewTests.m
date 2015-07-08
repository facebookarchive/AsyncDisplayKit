//
//  ASCollectionViewTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASCollectionView.h>

@interface ASCollectionViewTestDelegate : NSObject <ASCollectionViewDataSource, ASCollectionViewDelegate>

@property (nonatomic, assign) NSInteger numberOfSections;
@property (nonatomic, assign) NSInteger numberOfItemsInSection;

@end

@implementation ASCollectionViewTestDelegate

- (id)initWithNumberOfSections:(NSInteger)numberOfSections numberOfItemsInSection:(NSInteger)numberOfItemsInSection {
  if (self = [super init]) {
    _numberOfSections = numberOfSections;
    _numberOfItemsInSection = numberOfItemsInSection;
  }

  return self;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath {
  ASTextCellNode *textCellNode = [ASTextCellNode new];
  textCellNode.text = indexPath.description;

  return textCellNode;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return self.numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return self.numberOfItemsInSection;
}

@end

@interface ASCollectionViewTestController: UIViewController

@property (nonatomic, strong) ASCollectionViewTestDelegate *asyncDelegate;
@property (nonatomic, strong) ASCollectionView *collectionView;

@end

@implementation ASCollectionViewTestController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.asyncDelegate = [[ASCollectionViewTestDelegate alloc] initWithNumberOfSections:10 numberOfItemsInSection:10];

  self.collectionView = [[ASCollectionView alloc] initWithFrame:self.view.bounds
                                           collectionViewLayout:[UICollectionViewFlowLayout new]];
  self.collectionView.asyncDataSource = self.asyncDelegate;
  self.collectionView.asyncDelegate = self.asyncDelegate;

  [self.view addSubview:self.collectionView];
}

- (void)viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];

  self.collectionView.frame = self.view.bounds;
}

@end

@interface ASCollectionViewTests : XCTestCase

@end

@implementation ASCollectionViewTests

- (void)DISABLED_testCollectionViewController {
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];

  UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
  [containerView addSubview:testController.view];

  [testController.collectionView reloadData];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
}

@end
