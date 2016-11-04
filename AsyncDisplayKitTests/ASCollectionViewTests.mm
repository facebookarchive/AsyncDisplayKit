//
//  ASCollectionViewTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASCollectionView.h"
#import "ASCollectionData.h"
#import "ASCollectionDataController.h"
#import "ASCollectionViewFlowLayoutInspector.h"
#import "ASCellNode.h"
#import "ASCollectionNode.h"
#import "ASDisplayNode+Beta.h"
#import "ASSectionContext.h"
#import <vector>
#import <OCMock/OCMock.h>
#import "ASCollectionView+Undeprecated.h"
#import "ASCollectionInternal.h"

@interface ASTextCellNodeWithSetSelectedCounter : ASTextCellNode

@property (nonatomic, assign) NSUInteger setSelectedCounter;
@property (nonatomic, assign) NSUInteger applyLayoutAttributesCount;

@end

@implementation ASTextCellNodeWithSetSelectedCounter

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  _setSelectedCounter++;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  _applyLayoutAttributesCount++;
}

@end

@interface ASTestSectionContext : NSObject <ASSectionContext>

@property (nonatomic, assign) NSInteger sectionIndex;
@property (nonatomic, assign) NSInteger sectionGeneration;

@end

@implementation ASTestSectionContext

@synthesize sectionName = _sectionName, collectionView = _collectionView;

@end

@interface ASCollectionViewTestDelegate : NSObject <ASCollectionDataSource, ASCollectionDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, assign) BOOL useFunctionalStyle;


@property (nonatomic, assign) NSInteger sectionGeneration;
@property (nonatomic, strong) NSMutableArray<NSString *> *sections;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSString *> *> *items;
@end

@implementation ASCollectionViewTestDelegate {
}

- (id)initWithNumberOfSections:(NSInteger)numberOfSections numberOfItemsInSection:(NSInteger)numberOfItemsInSection {
  if (self = [super init]) {
    _sections = [NSMutableArray array];
    _items = [NSMutableArray array];

    for (NSInteger i = 0; i < 20; i++) {
      [_sections addObject:[NSUUID UUID].UUIDString];
      NSMutableArray *items = [NSMutableArray array];
      for (NSInteger i = 0; i < 10; i++) {
        [items addObject:[NSUUID UUID].UUIDString];
      }
      [_items addObject:items];
    }
    _sectionGeneration = 1;
  }

  return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
  if (aSelector == @selector(dataForCollectionNode:)) {
    return _useFunctionalStyle;
  } else if (aSelector == @selector(collectionNode:nodeForItemAtIndexPath:)) {
    return _useFunctionalStyle == NO;
  } else if (aSelector == @selector(collectionNode:nodeBlockForItemAtIndexPath:)) {
    return _useFunctionalStyle == NO;
  } else if (aSelector == @selector(collectionNode:numberOfItemsInSection:)) {
    return _useFunctionalStyle == NO;
  } else if (aSelector == @selector(numberOfSectionsInCollectionNode:)) {
    return _useFunctionalStyle == NO;
  } else if (aSelector == @selector(collectionNode:nodeForSupplementaryElementOfKind:atIndexPath:)) {
    return _useFunctionalStyle == NO;
  } else {
    return [super respondsToSelector:aSelector];
  }
}

- (ASCollectionData *)dataForCollectionNode:(ASCollectionNode *)collectionNode
{
  ASDisplayNodeAssert(_useFunctionalStyle, nil);
  ASCollectionData * data = [collectionNode createNewData];
  ASDisplayNodeAssert(data.mutableSections.count == 0, @"Should get a fresh data each time!");
  [_sections enumerateObjectsUsingBlock:^(NSString *sectionID, NSUInteger idx, BOOL * _Nonnull stop) {
    [data addSectionWithIdentifier:sectionID block:^(ASCollectionData * data) {
      NSString *headerID = [NSString stringWithFormat:@"Header for section %@", sectionID];
      [data addSupplementaryElementOfKind:UICollectionElementKindSectionHeader withIdentifier:headerID index:0 nodeBlock:^ASCellNode * _Nonnull{
        return [[ASCellNode alloc] init];
      }];
      for (NSString *item in _items[idx]) {
        [data addItemWithIdentifier:item
                          nodeBlock:^{
          ASTextCellNodeWithSetSelectedCounter *textCellNode = [[ASTextCellNodeWithSetSelectedCounter alloc] init];
          textCellNode.text = item;
          return textCellNode;
        }];
      }
    }];
  }];
  return data;
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertFalse(_useFunctionalStyle);
  ASTextCellNodeWithSetSelectedCounter *textCellNode = [ASTextCellNodeWithSetSelectedCounter new];
  textCellNode.text = indexPath.description;

  return textCellNode;
}


- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertFalse(_useFunctionalStyle);
  return ^{
    ASTextCellNodeWithSetSelectedCounter *textCellNode = [ASTextCellNodeWithSetSelectedCounter new];
    textCellNode.text = indexPath.description;
    return textCellNode;
  };
}

- (void)collectionView:(ASCollectionView *)collectionView willDisplayNode:(ASCellNode *)node forItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotNil(node.layoutAttributes, @"Expected layout attributes for node in %@ to be non-nil.", NSStringFromSelector(_cmd));
}

- (void)collectionView:(ASCollectionView *)collectionView didEndDisplayingNode:(ASCellNode *)node forItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotNil(node.layoutAttributes, @"Expected layout attributes for node in %@ to be non-nil.", NSStringFromSelector(_cmd));
}

- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode {
  ASDisplayNodeAssertFalse(_useFunctionalStyle);
  return _sections.count;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssertFalse(_useFunctionalStyle);
  return _items[section].count;
}

- (id<ASSectionContext>)collectionNode:(ASCollectionNode *)collectionNode contextForSection:(NSInteger)section
{
  ASTestSectionContext *context = [[ASTestSectionContext alloc] init];
  context.sectionGeneration = _sectionGeneration;
  context.sectionIndex = section;
  return context;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
  return CGSizeMake(100, 100);
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return [[ASCellNode alloc] init];
}

@end

@interface ASCollectionViewTestController: UIViewController

@property (nonatomic, strong) ASCollectionViewTestDelegate *asyncDelegate;
@property (nonatomic, strong) ASCollectionView *collectionView;
@property (nonatomic, strong) ASCollectionNode *collectionNode;

@end

@implementation ASCollectionViewTestController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  return [self initWithFunctionalStyle:NO];
}

- (instancetype)initWithFunctionalStyle:(BOOL)useFunctionalStyle
{
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    // Populate these immediately so that they're not unexpectedly nil during tests.
    self.asyncDelegate = [[ASCollectionViewTestDelegate alloc] initWithNumberOfSections:10 numberOfItemsInSection:10];
    self.asyncDelegate.useFunctionalStyle = useFunctionalStyle;
    id realLayout = [UICollectionViewFlowLayout new];
    id mockLayout = [OCMockObject partialMockForObject:realLayout];
    self.collectionNode = [[ASCollectionNode alloc] initWithFrame:self.view.bounds collectionViewLayout:mockLayout];
    self.collectionView = self.collectionNode.view;
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionNode.dataSource = self.asyncDelegate;
    self.collectionNode.delegate = self.asyncDelegate;
    
    [self.collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
    [self.view addSubview:self.collectionView];
  }
  return self;
}

@end

@interface ASCollectionView (InternalTesting)

- (NSArray *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController;

@end

@interface ASCollectionViewTests : XCTestCase

@end

@implementation ASCollectionViewTests

- (void)testDataSourceImplementsNecessaryMethods
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  
  id dataSource = [NSObject new];
  XCTAssertThrows((collectionView.asyncDataSource = dataSource));
}

- (void)testThatItSetsALayoutInspectorForFlowLayouts
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  XCTAssert(collectionView.layoutInspector != nil, @"should automatically set a layout delegate for flow layouts");
  XCTAssert([collectionView.layoutInspector isKindOfClass:[ASCollectionViewFlowLayoutInspector class]], @"should have a flow layout inspector by default");
}

- (void)testThatADefaultLayoutInspectorIsProvidedForCustomLayouts
{
  UICollectionViewLayout *layout = [[UICollectionViewLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  XCTAssert(collectionView.layoutInspector != nil, @"should automatically set a layout delegate for flow layouts");
  XCTAssert([collectionView.layoutInspector isKindOfClass:[ASCollectionViewLayoutInspector class]], @"should have a default layout inspector by default");
}

- (void)testThatRegisteringASupplementaryNodeStoresItForIntrospection
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  [collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  XCTAssertEqualObjects([collectionView supplementaryNodeKindsInDataController:nil], @[UICollectionElementKindSectionHeader]);
}

- (void)testReloadIfNeeded
{
  [ASDisplayNode setSuppressesInvalidCollectionUpdateExceptions:NO];

  __block ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];
  __block ASCollectionViewTestDelegate *del = testController.asyncDelegate;
  __block ASCollectionNode *cn = testController.collectionNode;

  void (^reset)() = ^void() {
    testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];
    del = testController.asyncDelegate;
    cn = testController.collectionNode;
  };

  // Check if the number of sections matches the data source
  XCTAssertEqual(cn.numberOfSections, del.sections.count, @"Section count doesn't match the data source");

  // Reset everything and then check if numberOfItemsInSection matches the data source
  reset();
  XCTAssertEqual([cn numberOfItemsInSection:0], del.items[0].count, @"Number of items in Section doesn't match the data source");

  // Reset and check if we can get the node corresponding to a specific indexPath
  reset();
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  ASTextCellNodeWithSetSelectedCounter *node = (ASTextCellNodeWithSetSelectedCounter*)[cn nodeForItemAtIndexPath:indexPath];
  XCTAssertEqualObjects(node.text, indexPath.description, @"Node's text should match the initial text it was created with");
}

- (void)testSelection
{
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [window setRootViewController:testController];
  [window makeKeyAndVisible];
  
  [testController.collectionView reloadDataImmediately];
  [testController.collectionView layoutIfNeeded];
  
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  ASCellNode *node = [testController.collectionView nodeForItemAtIndexPath:indexPath];

  NSInteger setSelectedCount = 0;
  // selecting node should select cell
  node.selected = YES;
  ++setSelectedCount;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath], @"Selecting node should update cell selection.");
  
  // deselecting node should deselect cell
  node.selected = NO;
  ++setSelectedCount;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] isEqualToArray:@[]], @"Deselecting node should update cell selection.");

  // selecting cell via collectionNode should select node
  ++setSelectedCount;
  [testController.collectionNode selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");
  
  // deselecting cell via collectionNode should deselect node
  ++setSelectedCount;
  [testController.collectionNode deselectItemAtIndexPath:indexPath animated:NO];
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // select the cell again, scroll down and back up, and check that the state persisted
  [testController.collectionNode selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  ++setSelectedCount;
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");

  testController.collectionNode.allowsMultipleSelection = YES;

  NSIndexPath *indexPath2 = [NSIndexPath indexPathForItem:1 inSection:0];
  ASCellNode *node2 = [testController.collectionView nodeForItemAtIndexPath:indexPath2];

  // selecting cell via collectionNode should select node
  [testController.collectionNode selectItemAtIndexPath:indexPath2 animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  XCTAssertTrue(node2.isSelected == YES, @"Selecting cell should update node selection.");

  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath] &&
                [[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath2],
                @"Selecting multiple cells should result in those cells being in the array of selectedItems.");

  // deselecting node should deselect cell
  node.selected = NO;
  ++setSelectedCount;
  XCTAssertTrue(![[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath] &&
                [[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath2], @"Deselecting node should update array of selectedItems.");

  node.selected = YES;
  ++setSelectedCount;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath], @"Selecting node should update cell selection.");

  node2.selected = NO;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath] &&
                ![[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath2], @"Deselecting node should update array of selectedItems.");

  // reload cell (-prepareForReuse is called) & check that selected state is preserved
  [testController.collectionView setContentOffset:CGPointMake(0,testController.collectionView.bounds.size.height)];
  [testController.collectionView layoutIfNeeded];
  [testController.collectionView setContentOffset:CGPointMake(0,0)];
  [testController.collectionView layoutIfNeeded];
  XCTAssertTrue(node.isSelected == YES, @"Reloaded cell should preserve state.");
  
  // deselecting cell should deselect node
  UICollectionViewCell *cell = [testController.collectionView cellForItemAtIndexPath:indexPath];
  cell.selected = NO;
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // check setSelected not called extra times
  XCTAssertTrue([(ASTextCellNodeWithSetSelectedCounter *)node setSelectedCounter] == (setSelectedCount + 1), @"setSelected: should not be called on node multiple times.");
}

- (void)testTuningParametersWithExplicitRangeMode
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  
  ASRangeTuningParameters minimumRenderParams = { .leadingBufferScreenfuls = 0.1, .trailingBufferScreenfuls = 0.1 };
  ASRangeTuningParameters minimumPreloadParams = { .leadingBufferScreenfuls = 0.1, .trailingBufferScreenfuls = 0.1 };
  ASRangeTuningParameters fullRenderParams = { .leadingBufferScreenfuls = 0.5, .trailingBufferScreenfuls = 0.5 };
  ASRangeTuningParameters fullPreloadParams = { .leadingBufferScreenfuls = 1, .trailingBufferScreenfuls = 0.5 };
  
  [collectionView setTuningParameters:minimumRenderParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeDisplay];
  [collectionView setTuningParameters:minimumPreloadParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypePreload];
  [collectionView setTuningParameters:fullRenderParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeDisplay];
  [collectionView setTuningParameters:fullPreloadParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypePreload];
  
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(minimumRenderParams,
                                                                    [collectionView tuningParametersForRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeDisplay]));
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(minimumPreloadParams,
                                                                    [collectionView tuningParametersForRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypePreload]));
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(fullRenderParams,
                                                                    [collectionView tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeDisplay]));
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(fullPreloadParams,
                                                                    [collectionView tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypePreload]));
}

- (void)testTuningParameters
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  
  ASRangeTuningParameters renderParams = { .leadingBufferScreenfuls = 1.2, .trailingBufferScreenfuls = 3.2 };
  ASRangeTuningParameters preloadParams = { .leadingBufferScreenfuls = 4.3, .trailingBufferScreenfuls = 2.3 };
  
  [collectionView setTuningParameters:renderParams forRangeType:ASLayoutRangeTypeDisplay];
  [collectionView setTuningParameters:preloadParams forRangeType:ASLayoutRangeTypePreload];
  
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(renderParams, [collectionView tuningParametersForRangeType:ASLayoutRangeTypeDisplay]));
  XCTAssertTrue(ASRangeTuningParametersEqualToRangeTuningParameters(preloadParams, [collectionView tuningParametersForRangeType:ASLayoutRangeTypePreload]));
}

/**
 * This may seem silly, but we had issues where the runtime sometimes wouldn't correctly report
 * conformances declared on categories.
 */
- (void)testThatCollectionNodeConformsToExpectedProtocols
{
  ASCollectionNode *node = [[ASCollectionNode alloc] initWithFrame:CGRectZero collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
  XCTAssert([node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)]);
}

#pragma mark - Update Validations

#define updateValidationTestPrologue \
  [ASDisplayNode setSuppressesInvalidCollectionUpdateExceptions:NO];\
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];\
  __unused ASCollectionViewTestDelegate *del = testController.asyncDelegate;\
  __unused ASCollectionView *cv = testController.collectionView;\
  __unused ASCollectionNode *cn = testController.collectionNode;\
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];\
  [window makeKeyAndVisible]; \
  window.rootViewController = testController;\
  \
  [testController.collectionView reloadDataImmediately];\
  [testController.collectionView layoutIfNeeded];

- (void)testThatSubmittingAValidInsertDoesNotThrowAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;

  [del.items[sectionCount - 1] addObject:[NSUUID UUID].UUIDString];
  XCTAssertNoThrow([cv insertItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount - 1] ]]);
}

- (void)testThatSubmittingAValidReloadDoesNotThrowAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;
  
  XCTAssertNoThrow([cv reloadItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount - 1] ]]);
}

- (void)testThatSubmittingAnInvalidInsertThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;
  
  XCTAssertThrows([cv insertItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount + 1] ]]);
}

- (void)testThatSubmittingAnInvalidDeleteThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;
  
  XCTAssertThrows([cv deleteItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount + 1] ]]);
}

- (void)testThatDeletingAndReloadingTheSameItemThrowsAnException
{
  updateValidationTestPrologue
  
  XCTAssertThrows([cv performBatchUpdates:^{
    NSArray *indexPaths = @[ [NSIndexPath indexPathForItem:0 inSection:0] ];
    [cv deleteItemsAtIndexPaths:indexPaths];
    [cv reloadItemsAtIndexPaths:indexPaths];
  } completion:nil]);
}

- (void)testThatHavingAnIncorrectSectionCountThrowsAnException
{
  updateValidationTestPrologue
  
  XCTAssertThrows([cv deleteSections:[NSIndexSet indexSetWithIndex:0]]);
}

- (void)testThatHavingAnIncorrectItemCountThrowsAnException
{
  updateValidationTestPrologue
  
  XCTAssertThrows([cv deleteItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:0] ]]);
}

- (void)testThatHavingAnIncorrectItemCountWithNoUpdatesThrowsAnException
{
  updateValidationTestPrologue
  
  XCTAssertThrows([cv performBatchUpdates:^{
    [del.items[0] addObject:[NSUUID UUID].UUIDString];
  } completion:nil]);
}

- (void)testThatInsertingAnInvalidSectionThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;

  XCTAssertThrows([cv performBatchUpdates:^{
    [del.sections addObject:[NSUUID UUID].UUIDString];
    [del.items addObject:[NSMutableArray array]];
    [cv insertSections:[NSIndexSet indexSetWithIndex:sectionCount + 1]];
  } completion:nil]);
}

- (void)testThatDeletingAndReloadingASectionThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;

  [del.sections removeLastObject];
  [del.items removeLastObject];
  XCTAssertThrows([cv performBatchUpdates:^{
    NSIndexSet *sections = [NSIndexSet indexSetWithIndex:sectionCount - 1];
    [cv reloadSections:sections];
    [cv deleteSections:sections];
  } completion:nil]);
}

- (void)testCellNodeLayoutAttributes
{
  updateValidationTestPrologue
  NSSet *nodeBatch1 = [NSSet setWithArray:[cn visibleNodes]];
  XCTAssertGreaterThan(nodeBatch1.count, 0);

  // Expect all visible nodes get 1 applyLayoutAttributes and have a non-nil value.
  for (ASTextCellNodeWithSetSelectedCounter *node in nodeBatch1) {
    XCTAssertEqual(node.applyLayoutAttributesCount, 1, @"Expected applyLayoutAttributes to be called exactly once for visible nodes.");
    XCTAssertNotNil(node.layoutAttributes, @"Expected layoutAttributes to be non-nil for visible cell node.");
  }

  // Scroll to next batch of items.
  NSIndexPath *nextIP = [NSIndexPath indexPathForItem:nodeBatch1.count inSection:0];
  [cv scrollToItemAtIndexPath:nextIP atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
  [cv layoutIfNeeded];

  // Ensure we scrolled far enough that all the old ones are offscreen.
  NSSet *nodeBatch2 = [NSSet setWithArray:[cn visibleNodes]];
  XCTAssertFalse([nodeBatch1 intersectsSet:nodeBatch2], @"Expected to scroll far away enough that all nodes are replaced.");

  // Now the nodes are no longer visible, expect their layout attributes are nil but not another applyLayoutAttributes call.
  for (ASTextCellNodeWithSetSelectedCounter *node in nodeBatch1) {
    XCTAssertEqual(node.applyLayoutAttributesCount, 1, @"Expected applyLayoutAttributes to be called exactly once for visible nodes, even after node is removed.");
    XCTAssertNil(node.layoutAttributes, @"Expected layoutAttributes to be nil for removed cell node.");
  }
}

- (void)testCellNodeIndexPathConsistency
{
  updateValidationTestPrologue

  // Test with a visible cell
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:2 inSection:0];
  ASCellNode *cell = [cn nodeForItemAtIndexPath:indexPath];

  // Check if cell's indexPath corresponds to the indexPath being tested
  XCTAssertTrue(cell.indexPath.section == indexPath.section && cell.indexPath.item == indexPath.item, @"Expected the cell's indexPath to be the same as the indexPath being tested.");

  // Remove an item prior to the cell's indexPath from the same section and check for indexPath consistency
  [del.items[indexPath.section] removeObjectAtIndex:0];
  [cn deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:indexPath.section]]];
  XCTAssertTrue(cell.indexPath.section == indexPath.section && cell.indexPath.item == (indexPath.item - 1), @"Expected the cell's indexPath to be updated once a cell with a lower index is deleted.");

  // Remove the section that includes the indexPath and check if the cell's indexPath is now nil
  [del.items removeObjectAtIndex:0];
  [del.sections removeObjectAtIndex:0];
  [cn deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
  XCTAssertNil(cell.indexPath, @"Expected the cell's indexPath to be nil once the section that contains the node is deleted.");

  // Run the same tests but with a non-displayed cell
  indexPath = [NSIndexPath indexPathForItem:2 inSection:(del.sections.count - 1)];
  cell = [cn nodeForItemAtIndexPath:indexPath];

  // Check if cell's indexPath corresponds to the indexPath being tested
  XCTAssertTrue(cell.indexPath.section == indexPath.section && cell.indexPath.item == indexPath.item, @"Expected the cell's indexPath to be the same as the indexPath in question.");

  // Remove an item prior to the cell's indexPath from the same section and check for indexPath consistency
  [del.items[indexPath.section] removeObjectAtIndex:0];
  [cn deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:indexPath.section]]];
  XCTAssertTrue(cell.indexPath.section == indexPath.section && cell.indexPath.item == (indexPath.item - 1), @"Expected the cell's indexPath to be updated once a cell with a lower index is deleted.");

  // Remove the section that includes the indexPath and check if the cell's indexPath is now nil
  [del.sections removeLastObject];
  [del.items removeLastObject];
  [cn deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
  XCTAssertNil(cell.indexPath, @"Expected the cell's indexPath to be nil once the section that contains the node is deleted.");
}

/**
 * https://github.com/facebook/AsyncDisplayKit/issues/2011
 *
 * If this ever becomes a pain to maintain, drop it. The underlying issue is tested by testThatLayerBackedSubnodesAreMarkedInvisibleBeforeDeallocWhenSupernodesViewIsRemovedFromHierarchyWhileBeingRetained
 */
- (void)testThatDisappearingSupplementariesWithLayerBackedNodesDontFailAssert
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UICollectionViewLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionNode *cn = [[ASCollectionNode alloc] initWithFrame:window.bounds collectionViewLayout:layout];
  ASCollectionView *cv = cn.view;
  cv.test_suppressCallbackImplementationAssertions = YES;


  __unused NSMutableSet *keepaliveNodes = [NSMutableSet set];
  id dataSource = [OCMockObject niceMockForProtocol:@protocol(ASCollectionDataSource)];
  static int nodeIdx = 0;
  [[[dataSource stub] andDo:^(NSInvocation *invocation) {
    __autoreleasing ASCellNode *suppNode = [[ASCellNode alloc] init];
    int thisNodeIdx = nodeIdx++;
    suppNode.debugName = [NSString stringWithFormat:@"Cell #%d", thisNodeIdx];
    [keepaliveNodes addObject:suppNode];

    ASDisplayNode *layerBacked = [[ASDisplayNode alloc] init];
    layerBacked.layerBacked = YES;
    layerBacked.debugName = [NSString stringWithFormat:@"Subnode #%d", thisNodeIdx];
    [suppNode addSubnode:layerBacked];
    [invocation setReturnValue:&suppNode];
  }] collectionNode:cn nodeForSupplementaryElementOfKind:UICollectionElementKindSectionHeader atIndexPath:OCMOCK_ANY];
  [[[dataSource stub] andReturnValue:[NSNumber numberWithInteger:1]] numberOfSectionsInCollectionView:cv];
  cv.asyncDataSource = dataSource;

  id delegate = [OCMockObject niceMockForProtocol:@protocol(UICollectionViewDelegateFlowLayout)];
  [[[delegate stub] andReturnValue:[NSValue valueWithCGSize:CGSizeMake(100, 100)]] collectionView:cv layout:OCMOCK_ANY referenceSizeForHeaderInSection:0];
  cv.asyncDelegate = delegate;

  [cv registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [window addSubview:cv];

  [window makeKeyAndVisible];

  for (NSInteger i = 0; i < 2; i++) {
    // NOTE: waitUntilAllUpdatesAreCommitted or reloadDataImmediately is not sufficient here!!
    XCTestExpectation *done = [self expectationWithDescription:[NSString stringWithFormat:@"Reload #%td complete", i]];
    [cv reloadDataWithCompletion:^{
      [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
  }

}

- (void)testThatNodeCalculatedSizesAreUpdatedBeforeFirstPrepareLayoutAfterRotation
{
  updateValidationTestPrologue
  id layout = cv.collectionViewLayout;
  CGSize initialItemSize = [cv nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]].calculatedSize;
  CGSize initialCVSize = cv.bounds.size;

  // Capture the node size before first call to prepareLayout after frame change.
  __block CGSize itemSizeAtFirstLayout = CGSizeZero;
  __block CGSize boundsSizeAtFirstLayout = CGSizeZero;
  [[[[layout expect] andDo:^(NSInvocation *) {
    itemSizeAtFirstLayout = [cv nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]].calculatedSize;
    boundsSizeAtFirstLayout = [cv bounds].size;
  }] andForwardToRealObject] prepareLayout];

  // Rotate the device
  UIDeviceOrientation oldDeviceOrientation = [[UIDevice currentDevice] orientation];
  [[UIDevice currentDevice] setValue:@(UIDeviceOrientationLandscapeLeft) forKey:@"orientation"];

  CGSize finalItemSize = [cv nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]].calculatedSize;
  CGSize finalCVSize = cv.bounds.size;
  XCTAssertNotEqualObjects(NSStringFromCGSize(initialItemSize),  NSStringFromCGSize(itemSizeAtFirstLayout));
  XCTAssertNotEqualObjects(NSStringFromCGSize(initialCVSize),  NSStringFromCGSize(boundsSizeAtFirstLayout));
  XCTAssertEqualObjects(NSStringFromCGSize(itemSizeAtFirstLayout), NSStringFromCGSize(finalItemSize));
  XCTAssertEqualObjects(NSStringFromCGSize(boundsSizeAtFirstLayout), NSStringFromCGSize(finalCVSize));
  [layout verify];

  // Teardown
  [[UIDevice currentDevice] setValue:@(oldDeviceOrientation) forKey:@"orientation"];
}

/**
 * See corresponding test in ASUICollectionViewTests
 *
 * @discussion Currently, we do not replicate UICollectionView's call order (outer, inner0, inner1, ...)
 *   and instead call (inner0, inner1, outer, ...). This is because we primarily provide a
 *   beginUpdates/endUpdatesWithCompletion: interface (like UITableView). With UICollectionView's
 *   performBatchUpdates:completion:, the completion block is enqueued at -beginUpdates time.
 *   With our tableView-like scheme, the completion block is provided at -endUpdates time
 *   and it is naturally enqueued at this time. It is assumed that this is an acceptable deviation,
 *   and that developers do not expect a particular completion order guarantee.
 */
- (void)testThatNestedBatchCompletionsAreCalledInOrder
{
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];

  ASCollectionView *cv = testController.collectionView;

  XCTestExpectation *inner0 = [self expectationWithDescription:@"Inner completion 0 is called"];
  XCTestExpectation *inner1 = [self expectationWithDescription:@"Inner completion 1 is called"];
  XCTestExpectation *outer = [self expectationWithDescription:@"Outer completion is called"];

  NSMutableArray<XCTestExpectation *> *completions = [NSMutableArray array];

  [cv performBatchUpdates:^{
    [cv performBatchUpdates:^{

    } completion:^(BOOL finished) {
      [completions addObject:inner0];
      [inner0 fulfill];
    }];
    [cv performBatchUpdates:^{

    } completion:^(BOOL finished) {
      [completions addObject:inner1];
      [inner1 fulfill];
    }];
  } completion:^(BOOL finished) {
    [completions addObject:outer];
    [outer fulfill];
  }];

  [self waitForExpectationsWithTimeout:5 handler:nil];
  XCTAssertEqualObjects(completions, (@[ inner0, inner1, outer ]), @"Expected completion order to be correct");
}

#pragma mark - ASSectionContext tests

- (void)testThatSectionContextsAreCorrectAfterTheInitialLayout
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;
  for (NSInteger section = 0; section < sectionCount; section++) {
    ASTestSectionContext *context = (ASTestSectionContext *)[cn contextForSection:section];
    XCTAssertNotNil(context);
    XCTAssertEqual(context.sectionGeneration, 1);
    XCTAssertEqual(context.sectionIndex, section);
  }
}

- (void)testThatSectionContextsAreCorrectAfterSectionMove
{
  updateValidationTestPrologue
  NSInteger sectionCount = del.sections.count;
  NSInteger originalSection = sectionCount - 1;
  NSInteger toSection = 0;

  del.sectionGeneration++;
  [cv moveSection:originalSection toSection:toSection];
  [cv waitUntilAllUpdatesAreCommitted];
  
  // Only test left moving
  XCTAssertTrue(toSection < originalSection);
  ASTestSectionContext *movedSectionContext = (ASTestSectionContext *)[cn contextForSection:toSection];
  XCTAssertNotNil(movedSectionContext);
  // ASCollectionView currently uses ASChangeSetDataController which splits a move operation to a pair of delete and insert ones.
  // So this movedSectionContext is newly loaded and thus is second generation.
  XCTAssertEqual(movedSectionContext.sectionGeneration, 2);
  XCTAssertEqual(movedSectionContext.sectionIndex, toSection);
  
  for (NSInteger section = toSection + 1; section <= originalSection && section < sectionCount; section++) {
    ASTestSectionContext *context = (ASTestSectionContext *)[cn contextForSection:section];
    XCTAssertNotNil(context);
    XCTAssertEqual(context.sectionGeneration, 1);
    // This section context was shifted to the right
    XCTAssertEqual(context.sectionIndex, (section - 1));
  }
}

- (void)testThatSectionContextsAreCorrectAfterReloadData
{
  updateValidationTestPrologue
  
  del.sectionGeneration++;
  [cv reloadDataImmediately];
  
  NSInteger sectionCount = del.sections.count;
  for (NSInteger section = 0; section < sectionCount; section++) {
    ASTestSectionContext *context = (ASTestSectionContext *)[cn contextForSection:section];
    XCTAssertNotNil(context);
    XCTAssertEqual(context.sectionGeneration, 2);
    XCTAssertEqual(context.sectionIndex, section);
  }
}

- (void)testThatSectionContextsAreCorrectAfterReloadASection
{
  updateValidationTestPrologue
  NSInteger sectionToReload = 0;
  
  del.sectionGeneration++;
  [cv reloadSections:[NSIndexSet indexSetWithIndex:sectionToReload]];
  [cv waitUntilAllUpdatesAreCommitted];
  
  NSInteger sectionCount = del.sections.count;
  for (NSInteger section = 0; section < sectionCount; section++) {
    ASTestSectionContext *context = (ASTestSectionContext *)[cn contextForSection:section];
    XCTAssertNotNil(context);
    XCTAssertEqual(context.sectionGeneration, section != sectionToReload ? 1 : 2);
    XCTAssertEqual(context.sectionIndex, section);
  }
}

/// See the same test in ASUICollectionViewTests for the reference behavior.
- (void)testThatIssuingAnUpdateBeforeInitialReloadIsAcceptable
{
  ASCollectionViewTestDelegate *del = [[ASCollectionViewTestDelegate alloc] initWithNumberOfSections:0 numberOfItemsInSection:0];
  ASCollectionView *cv = [[ASCollectionView alloc] initWithCollectionViewLayout:[UICollectionViewFlowLayout new]];
  cv.asyncDataSource = del;
  cv.asyncDelegate = del;

  // Add a section to the data source
  [del.items addObject:[NSMutableArray array]];
  [del.sections addObject:[NSUUID UUID].UUIDString];
  // Attempt to insert section into collection view. We ignore it to workaround
  // the bug demonstrated by
  // ASUICollectionViewTests.testThatIssuingAnUpdateBeforeInitialReloadIsUnacceptable
  XCTAssertNoThrow([cv insertSections:[NSIndexSet indexSetWithIndex:0]]);
}

- (void)testThatNodeAtIndexPathIsCorrectImmediatelyAfterSubmittingUpdate
{
  updateValidationTestPrologue
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];

  // Insert an item and assert nodeForItemAtIndexPath: immediately returns new node
  ASCellNode *oldNode = [cn nodeForItemAtIndexPath:indexPath];
  XCTAssertNotNil(oldNode);
  [del.items[0] addObject:[NSUUID UUID].UUIDString];
  [cv insertItemsAtIndexPaths:@[ indexPath ]];
  ASCellNode *newNode = [cn nodeForItemAtIndexPath:indexPath];
  XCTAssertNotNil(newNode);
  XCTAssertNotEqualObjects(oldNode, newNode);

  // Delete all sections and assert nodeForItemAtIndexPath: immediately returns nil
  NSIndexSet *sections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, del.sections.count)];
  [del.sections removeAllObjects];
  [del.items removeAllObjects];
  [cv deleteSections:sections];
  XCTAssertNil([cn nodeForItemAtIndexPath:indexPath]);
}

- (void)DISABLED_testThatSupplementaryNodeAtIndexPathIsCorrectImmediatelyAfterSubmittingUpdate
{
  updateValidationTestPrologue
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  ASCellNode *oldHeader = [cv supplementaryNodeForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
  XCTAssertNotNil(oldHeader);

  // Reload the section and ensure that the new header is loaded
  [cv reloadSections:[NSIndexSet indexSetWithIndex:0]];
  ASCellNode *newHeader = [cv supplementaryNodeForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
  XCTAssertNotNil(newHeader);
  XCTAssertNotEqualObjects(oldHeader, newHeader);
}

- (void)testThatNilBatchUpdatesCanBeSubmitted
{
  __block ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];
  __block ASCollectionNode *cn = testController.collectionNode;
  
  // Passing nil blocks should not crash
  [cn performBatchUpdates:nil completion:nil];
  [cn performBatchAnimated:NO updates:nil completion:nil];
}

- (void)testFunctionalDataLoad
{
  ASCollectionViewTestController *ctrl = [[ASCollectionViewTestController alloc] initWithFunctionalStyle:YES];
  ASCollectionViewTestDelegate *del = ctrl.asyncDelegate;

  XCTAssertEqual(del.sections.count, ctrl.collectionNode.numberOfSections);
  [del.items enumerateObjectsUsingBlock:^(NSMutableArray<NSString *> * itemArray, NSUInteger section, BOOL * _Nonnull stop) {
    XCTAssertEqual(itemArray.count, [ctrl.collectionNode numberOfItemsInSection:section]);
  }];
}

- (void)testFunctionalDataUpdate
{
  ASCollectionViewTestController *ctrl = [[ASCollectionViewTestController alloc] initWithFunctionalStyle:YES];
  ASCollectionViewTestDelegate *del = ctrl.asyncDelegate;

  // Weak so that compiler won't whine about retain cycle.
  __weak ASCollectionNode *node = ctrl.collectionNode;
  [ctrl.view layoutIfNeeded];
  [node waitUntilAllUpdatesAreCommitted];
  // Insert section at index 1
  [del.sections insertObject:@"Section X" atIndex:1];
  [del.items insertObject:[NSMutableArray arrayWithObjects:@"Item X", @"Item Y", nil] atIndex:1];
  XCTestExpectation *updateCompletionExpectation = [self expectationWithDescription:@"Update did finish"];
  [node performBatchUpdates:nil completion:^(BOOL finished) {
    XCTAssertEqual([node.view numberOfSections], del.sections.count);
    [del.items enumerateObjectsUsingBlock:^(NSMutableArray<NSString *> * _Nonnull items, NSUInteger section, BOOL * _Nonnull stop) {
      XCTAssertEqual([node.view numberOfItemsInSection:section], items.count);
    }];
    [updateCompletionExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:60 handler:nil];
}

@end
