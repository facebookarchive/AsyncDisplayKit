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
#import "ASCollectionDataController.h"
#import "ASCollectionViewFlowLayoutInspector.h"
#import "ASCellNode.h"
#import "ASCollectionNode.h"
#import "ASViewController.h"
#import "ASDisplayNode+Beta.h"
#import <vector>
#import <OCMock/OCMock.h>
#import "ASInternalHelpers.h"
#import "ASXCTExtensions.h"

static NSInteger const kDefaultNumberOfSections = 2;
static NSInteger const kDefaultNumberOfItemsPerSection = 3;

@interface ASTextCellNodeWithSetSelectedCounter : ASTextCellNode

@property (nonatomic, assign) NSUInteger setSelectedCounter;

@end

@implementation ASTextCellNodeWithSetSelectedCounter

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  _setSelectedCounter++;
}

@end

@interface ASCollectionTestController: ASViewController<ASCollectionNode *> <ASCollectionDelegate, ASCollectionDataSource>

@property (nonatomic, strong, readonly) ASCollectionView *collectionView;

@end

@implementation ASCollectionTestController {
  @package
  std::vector<NSInteger> _itemCounts;
}

- (instancetype)init
{
  id realLayout = [[UICollectionViewFlowLayout alloc] init];
  id mockLayout = [OCMockObject partialMockForObject:realLayout];
  self = [super initWithNode:[[ASCollectionNode alloc] initWithCollectionViewLayout:mockLayout]];
  if (self) {
    for (NSInteger i = 0; i < kDefaultNumberOfSections; i++) {
      _itemCounts.push_back(kDefaultNumberOfItemsPerSection);
    }
    self.node.delegate = self;
    self.node.dataSource = self;
  }
  return self;
}

- (ASCollectionView *)collectionView
{
  return (ASCollectionView *)self.view;
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath {
  return ^{
    ASTextCellNodeWithSetSelectedCounter *textCellNode = [ASTextCellNodeWithSetSelectedCounter new];
    textCellNode.text = indexPath.description;
    return textCellNode;
  };
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return _itemCounts.size();
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return _itemCounts[section];
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
  
  dataSource = [OCMockObject niceMockForProtocol:@protocol(ASCollectionDataSource)];
  XCTAssertNoThrow((collectionView.asyncDataSource = dataSource));
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

- (void)testSelection
{
  ASCollectionTestController *ctrl = [[ASCollectionTestController alloc] init];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [window setRootViewController:ctrl];
  [window makeKeyAndVisible];
  
  [ctrl.collectionView reloadDataImmediately];
  [ctrl.collectionView layoutIfNeeded];
  
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  ASCellNode *node = [ctrl.collectionView nodeForItemAtIndexPath:indexPath];
  
  // selecting node should select cell
  node.selected = YES;
  XCTAssertTrue([[ctrl.collectionView indexPathsForSelectedItems] containsObject:indexPath], @"Selecting node should update cell selection.");
  
  // deselecting node should deselect cell
  node.selected = NO;
  XCTAssertTrue([[ctrl.collectionView indexPathsForSelectedItems] isEqualToArray:@[]], @"Deselecting node should update cell selection.");

  // selecting cell via collectionView should select node
  [ctrl.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");
  
  // deselecting cell via collectionView should deselect node
  [ctrl.collectionView deselectItemAtIndexPath:indexPath animated:NO];
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // select the cell again, scroll down and back up, and check that the state persisted
  [ctrl.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");
  
  // reload cell (-prepareForReuse is called) & check that selected state is preserved
  [ctrl.collectionView setContentOffset:CGPointMake(0,ctrl.collectionView.bounds.size.height)];
  [ctrl.collectionView layoutIfNeeded];
  [ctrl.collectionView setContentOffset:CGPointMake(0,0)];
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertTrue(node.isSelected == YES, @"Reloaded cell should preserve state.");
  
  // deselecting cell should deselect node
  UICollectionViewCell *cell = [ctrl.collectionView cellForItemAtIndexPath:indexPath];
  cell.selected = NO;
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // check setSelected not called extra times
  XCTAssertTrue([(ASTextCellNodeWithSetSelectedCounter *)node setSelectedCounter] == 6, @"setSelected: should not be called on node multiple times.");
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
  ASCollectionTestController *ctrl = [[ASCollectionTestController alloc] init];\
  __unused ASCollectionView *cv = ctrl.collectionView;\
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];\
  [window makeKeyAndVisible]; \
  window.rootViewController = ctrl;\
  \
  [ctrl.collectionView reloadDataImmediately];\
  [ctrl.collectionView layoutIfNeeded];

- (void)testThatSubmittingAValidInsertDoesNotThrowAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
  ctrl->_itemCounts[sectionCount - 1]++;
  XCTAssertNoThrow([cv insertItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount - 1] ]]);
}

- (void)testThatSubmittingAValidReloadDoesNotThrowAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
  XCTAssertNoThrow([cv reloadItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount - 1] ]]);
}

- (void)testThatSubmittingAnInvalidInsertThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
  XCTAssertThrows([cv insertItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:sectionCount + 1] ]]);
}

- (void)testThatSubmittingAnInvalidDeleteThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
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
    ctrl->_itemCounts[0]++;
  } completion:nil]);
}

- (void)testThatInsertingAnInvalidSectionThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
  ctrl->_itemCounts.push_back(10);
  XCTAssertThrows([cv performBatchUpdates:^{
    [cv insertSections:[NSIndexSet indexSetWithIndex:sectionCount + 1]];
  } completion:nil]);
}

- (void)testThatDeletingAndReloadingASectionThrowsAnException
{
  updateValidationTestPrologue
  NSInteger sectionCount = ctrl->_itemCounts.size();
  
  ctrl->_itemCounts.pop_back();
  XCTAssertThrows([cv performBatchUpdates:^{
    NSIndexSet *sections = [NSIndexSet indexSetWithIndex:sectionCount - 1];
    [cv reloadSections:sections];
    [cv deleteSections:sections];
  } completion:nil]);
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
  ASCollectionView *cv = [[ASCollectionView alloc] initWithFrame:window.bounds collectionViewLayout:layout];


  __unused NSMutableSet *keepaliveNodes = [NSMutableSet set];
  id dataSource = [OCMockObject niceMockForProtocol:@protocol(ASCollectionDataSource)];
  static int nodeIdx = 0;
  [[[dataSource stub] andDo:^(NSInvocation *invocation) {
    __autoreleasing ASCellNode *suppNode = [[ASCellNode alloc] init];
    int thisNodeIdx = nodeIdx++;
    suppNode.name = [NSString stringWithFormat:@"Cell #%d", thisNodeIdx];
    [keepaliveNodes addObject:suppNode];

    ASDisplayNode *layerBacked = [[ASDisplayNode alloc] init];
    layerBacked.layerBacked = YES;
    layerBacked.name = [NSString stringWithFormat:@"Subnode #%d", thisNodeIdx];
    [suppNode addSubnode:layerBacked];
    [invocation setReturnValue:&suppNode];
  }] collectionView:cv nodeForSupplementaryElementOfKind:UICollectionElementKindSectionHeader atIndexPath:OCMOCK_ANY];
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

- (void)testWaitingForAllUpdatesBeforeFirstLayout
{
  ASCollectionTestController * ctrl = [[ASCollectionTestController alloc] init];
  XCTAssertFalse(CGRectIsEmpty(ctrl.collectionView.bounds));
  
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  
  [ctrl.collectionView waitUntilAllUpdatesAreCommitted];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
}

- (void)testWaitForUpdatesDuringNextLayoutFirstLoad
{
  ASCollectionTestController * ctrl = [[ASCollectionTestController alloc] init];
  [ctrl.collectionView waitForUpdatesDuringNextLayoutPass];
  XCTAssertFalse(CGRectIsEmpty(ctrl.collectionView.bounds));
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  XCTAssertGreaterThan(ctrl.collectionView.subviews.count, 2);
}

- (void)testWaitForUpdatesDuringNextLayoutSubsequentLoad
{
  ASCollectionTestController * ctrl = [[ASCollectionTestController alloc] init];
  [ctrl.collectionView waitForUpdatesDuringNextLayoutPass];
  
  // Setup initial data
  XCTAssertFalse(CGRectIsEmpty(ctrl.collectionView.bounds));
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  [ctrl.collectionView reloadDataImmediately];
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  XCTAssertGreaterThan(ctrl.collectionView.subviews.count, 2);
  
  // Insert an item and assert that wait works.
  NSIndexPath *newItem = [NSIndexPath indexPathForItem:kDefaultNumberOfItemsPerSection inSection:0];
  ctrl->_itemCounts[0] += 1;
  [ctrl.collectionView insertItemsAtIndexPaths:@[ newItem ]];
  [ctrl.collectionView waitForUpdatesDuringNextLayoutPass];
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:newItem]);
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:newItem]);
}

- (void)testSubsequentLoadsAreAsyncByDefault
{
  ASCollectionTestController * ctrl = [[ASCollectionTestController alloc] init];
  [ctrl.collectionView waitForUpdatesDuringNextLayoutPass];
  
  // Setup initial data
  XCTAssertFalse(CGRectIsEmpty(ctrl.collectionView.bounds));
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  [ctrl.collectionView reloadDataImmediately];
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  XCTAssertGreaterThan(ctrl.collectionView.subviews.count, 2);
  
  // Insert an item and assert that not waiting causes the update to happen after the layout.
  NSIndexPath *newItem = [NSIndexPath indexPathForItem:kDefaultNumberOfItemsPerSection inSection:0];
  ctrl->_itemCounts[0] += 1;
  [ctrl.collectionView insertItemsAtIndexPaths:@[ newItem ]];
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:newItem]);
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:newItem]);
  
  // Now we explicitly wait and we'll get our new item.
  [ctrl.collectionView waitUntilAllUpdatesAreCommitted];
  XCTAssertNotNil([ctrl.collectionView nodeForItemAtIndexPath:newItem]);
}

- (void)testInitialDataLoadIsAsync
{
  ASCollectionTestController * ctrl = [[ASCollectionTestController alloc] init];
  XCTAssertFalse(CGRectIsEmpty(ctrl.collectionView.bounds));
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  [ctrl.collectionView layoutIfNeeded];
  XCTAssertNil([ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]);
  XCTAssertLessThanOrEqual(ctrl.collectionView.subviews.count, 2);
  [self expectationForPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
    return [ctrl.collectionView nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]!= nil;
  }] evaluatedWithObject:(id)kCFNull handler:nil];
  [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testThatNodeCalculatedSizesAreUpdatedBeforeFirstPrepareLayoutAfterRotation
{
  updateValidationTestPrologue
  id layout = cv.collectionViewLayout;
  CGSize initialItemSize = [cv calculatedSizeForNodeAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  CGSize initialCVSize = cv.bounds.size;

  // Capture the node size before first call to prepareLayout after frame change.
  __block CGSize itemSizeAtFirstLayout = CGSizeZero;
  __block CGSize boundsSizeAtFirstLayout = CGSizeZero;
  [[[[layout expect] andDo:^(NSInvocation *) {
    itemSizeAtFirstLayout = [cv calculatedSizeForNodeAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    boundsSizeAtFirstLayout = [cv bounds].size;
  }] andForwardToRealObject] prepareLayout];

  // Rotate the device
  UIDeviceOrientation oldDeviceOrientation = [[UIDevice currentDevice] orientation];
  [[UIDevice currentDevice] setValue:@(UIDeviceOrientationLandscapeLeft) forKey:@"orientation"];

  CGSize finalItemSize = [cv calculatedSizeForNodeAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  CGSize finalCVSize = cv.bounds.size;
  
  ASXCTAssertNotEqualSizes(initialItemSize, itemSizeAtFirstLayout);
  ASXCTAssertNotEqualSizes(initialCVSize, boundsSizeAtFirstLayout);
  ASXCTAssertEqualSizes(itemSizeAtFirstLayout, finalItemSize);
  ASXCTAssertEqualSizes(boundsSizeAtFirstLayout, finalCVSize);
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

@end
