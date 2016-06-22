//
//  ASTableViewThrashTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 6/21/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

@import XCTest;
#import <AsyncDisplayKit/AsyncDisplayKit.h>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

#define USE_UIKIT_REFERENCE 0

#define kInitialSectionCount 20
#define kInitialItemCount 20

#if USE_UIKIT_REFERENCE
#define kCellReuseID @"ASThrashTestCellReuseID"
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static NSString *ASThrashArrayDescription(NSArray *array) {
  NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
  NSInteger i = 0;
  for (id obj in array) {
    [str appendFormat:@"\t[%ld]: \"%@\",\n", i, obj];
    i += 1;
  }
  [str appendString:@")"];
  return str;
}
#pragma clang diagnostic pop

@interface ASThrashTestItem: NSObject
#if USE_UIKIT_REFERENCE
/// This is used to identify the row with the table view (UIKit only).
@property (nonatomic, readonly) CGFloat rowHeight;
#endif
@end

@implementation ASThrashTestItem

- (instancetype)init {
  self = [super init];
  if (self != nil) {
#if USE_UIKIT_REFERENCE
    _rowHeight = arc4random_uniform(500);
#endif
  }
  return self;
}

+ (NSMutableArray <ASThrashTestItem *> *)itemsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestItem alloc] init]];
  }
  return result;
}

- (NSString *)description {
#if USE_UIKIT_REFERENCE
  return [NSString stringWithFormat:@"<Item: rowHeight=%lu>", (unsigned long)self.rowHeight];
#else
  return [NSString stringWithFormat:@"<Item: %p>", self];
#endif
}

@end

@interface ASThrashTestSection: NSObject
@property (nonatomic, strong, readonly) NSMutableArray *items;

/// This is used to identify the section with the table view.
@property (nonatomic, readonly) CGFloat headerHeight;
@end

@implementation ASThrashTestSection

- (instancetype)initWithCount:(NSInteger)count {
  self = [super init];
  if (self != nil) {
    _items = [ASThrashTestItem itemsWithCount:count];
    _headerHeight = arc4random_uniform(500) + 1;
  }
  return self;
}

- (instancetype)init {
  return [self initWithCount:0];
}

+ (NSMutableArray <ASThrashTestSection *> *)sectionsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestSection alloc] initWithCount:kInitialItemCount]];
  }
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<Section: headerHeight=%lu, itemCount=%lu>", (unsigned long)self.headerHeight, (unsigned long)self.items.count];
}

@end

#if !USE_UIKIT_REFERENCE
@interface ASThrashTestNode: ASCellNode
@property (nonatomic, strong) ASThrashTestItem *item;
@end

@implementation ASThrashTestNode

@end
#endif

@interface ASThrashDataSource: NSObject
#if USE_UIKIT_REFERENCE
<UITableViewDataSource, UITableViewDelegate>
#else
<ASTableDataSource, ASTableDelegate>
#endif
@property (nonatomic, strong, readonly) NSMutableArray <ASThrashTestSection *> *data;
@end


@implementation ASThrashDataSource

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _data = [ASThrashTestSection sectionsWithCount:kInitialSectionCount];
  }
  return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.data[section].items.count;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return self.data.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return self.data[section].headerHeight;
}

#if USE_UIKIT_REFERENCE

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  return [tableView dequeueReusableCellWithIdentifier:kCellReuseID forIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  ASThrashTestItem *item = self.data[indexPath.section].items[indexPath.item];
  return item.rowHeight;
}

#else

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath {
  ASThrashTestItem *item = self.data[indexPath.section].items[indexPath.item];
  return ^{
    ASThrashTestNode *node = [[ASThrashTestNode alloc] init];
    node.item = item;
    return node;
  };
}

#endif

@end


@implementation NSIndexSet (ASThrashHelpers)

- (NSArray <NSIndexPath *> *)indexPathsInSection:(NSInteger)section {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
  [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [result addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
  }];
  return result;
}

@end

@interface ASTableViewThrashTests: XCTestCase
@end

@implementation ASTableViewThrashTests {
  ASThrashDataSource *ds;
  UIWindow *window;
#if USE_UIKIT_REFERENCE
  UITableView *tableView;
#else
  ASTableView *tableView;
#endif
  
  NSInteger minimumItemCount;
  NSInteger minimumSectionCount;
  float fickleness;
}

- (void)setUp {
  minimumItemCount = 5;
  minimumSectionCount = 3;
  fickleness = 0.1;
  window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  ds = [[ASThrashDataSource alloc] init];
#if USE_UIKIT_REFERENCE
  tableView = [[UITableView alloc] initWithFrame:window.bounds style:UITableViewStyleGrouped];
  [window addSubview:tableView];
  tableView.dataSource = ds;
  tableView.delegate = ds;
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseID];
  [window layoutIfNeeded];
#else
  ASTableNode *tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
  tableView = tableNode.view;
  tableNode.frame = window.bounds;
  [window addSubnode:tableNode];
  tableNode.dataSource = ds;
  tableNode.delegate = ds;
  [tableView reloadDataImmediately];
#endif

}

- (void)testInitialDataRead {
  [self verifyTableStateWithHierarchy];
}

- (void)DISABLED_testThrashingWildly {
  for (NSInteger i = 0; i < 100; i++) {
    [self setUp];
    [self _testThrashingWildly];
    [self tearDown];
  }
}

- (void)_testThrashingWildly {
  [self verifyTableStateWithHierarchy];
  LOG(@"\n*******\nNext Iteration\n*******\nOld data: %@", ASThrashArrayDescription(ds.data));
  
  // NOTE: This is not a deep copy, so these sections will still have their
  // item counts updated throughout the update.
  NSArray *oldSections = [ds.data copy];
  
  NSMutableArray <NSMutableIndexSet *> *deletedItems = [NSMutableArray array];
  NSMutableArray <NSMutableIndexSet *> *replacedItems = [NSMutableArray array];
  NSMutableArray <NSMutableIndexSet *> *insertedItems = [NSMutableArray array];
  
  // Randomly reload some items
  for (ASThrashTestSection *section in ds.data) {
    NSMutableIndexSet *indexes = [self randomIndexesLessThan:section.items.count probability:fickleness insertMode:NO];
    NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
    [section.items replaceObjectsAtIndexes:indexes withObjects:newItems];
    [replacedItems addObject:indexes];
  }
  
  // Randomly replace some sections
  NSMutableIndexSet *replacedSections = [self randomIndexesLessThan:ds.data.count probability:fickleness insertMode:NO];
  NSArray *replacingSections = [ASThrashTestSection sectionsWithCount:replacedSections.count];
  [ds.data replaceObjectsAtIndexes:replacedSections withObjects:replacingSections];
  
  // Randomly delete some items
  [ds.data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
    if (section.items.count >= minimumItemCount) {
      NSMutableIndexSet *indexes = [self randomIndexesLessThan:section.items.count probability:fickleness insertMode:NO];
      
      /// Cannot reload & delete the same item.
      [indexes removeIndexes:replacedItems[idx]];
      
      [section.items removeObjectsAtIndexes:indexes];
      [deletedItems addObject:indexes];
    } else {
      [deletedItems addObject:[NSMutableIndexSet indexSet]];
    }
  }];
  
  // Randomly delete some sections
  NSMutableIndexSet *deletedSections = nil;
  if (ds.data.count >= minimumSectionCount) {
    deletedSections = [self randomIndexesLessThan:ds.data.count probability:fickleness insertMode:NO];
  } else {
    deletedSections = [NSMutableIndexSet indexSet];
  }
  // Cannot replace & delete the same section.
  [deletedSections removeIndexes:replacedSections];
  
  // Cannot delete/replace item in deleted/replaced section
  [deletedSections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [replacedItems[idx] removeAllIndexes];
    [deletedItems[idx] removeAllIndexes];
  }];
  [replacedSections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [replacedItems[idx] removeAllIndexes];
    [deletedItems[idx] removeAllIndexes];
  }];
  [ds.data removeObjectsAtIndexes:deletedSections];
  
  // Randomly insert some sections
  NSMutableIndexSet *insertedSections = [self randomIndexesLessThan:(ds.data.count + 1) probability:fickleness insertMode:YES];
  NSArray *newSections = [ASThrashTestSection sectionsWithCount:insertedSections.count];
  [ds.data insertObjects:newSections atIndexes:insertedSections];
  
  // Randomly insert some items
  for (ASThrashTestSection *section in ds.data) {
    // Only insert items into the old sections – not replaced/inserted sections.
    if ([oldSections containsObject:section]) {
      NSMutableIndexSet *indexes = [self randomIndexesLessThan:(section.items.count + 1) probability:fickleness insertMode:YES];
      NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
      [section.items insertObjects:newItems atIndexes:indexes];
      [insertedItems addObject:indexes];
    } else {
      [insertedItems addObject:[NSMutableIndexSet indexSet]];
    }
  }
  
  LOG(@"Deleted items: %@\nDeleted sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@", ASThrashArrayDescription(deletedItems), deletedSections, ASThrashArrayDescription(replacedItems), replacedSections, ASThrashArrayDescription(insertedItems), insertedSections, ASThrashArrayDescription(ds.data));
  
  // TODO: Submit changes in random order, randomly chunked up
  
  [tableView beginUpdates];
  [insertedItems enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:idx];
    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [tableView insertSections:insertedSections withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView reloadSections:replacedSections withRowAnimation:UITableViewRowAnimationNone];
  
  [deletedItems enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [replacedItems enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [tableView endUpdates];
#if !USE_UIKIT_REFERENCE
  [tableView waitUntilAllUpdatesAreCommitted];
#endif
  [self verifyTableStateWithHierarchy];
}

/// `insertMode` means that for each index selected, the max goes up by one.
- (NSMutableIndexSet *)randomIndexesLessThan:(NSInteger)max probability:(float)probability insertMode:(BOOL)insertMode {
  NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];
  u_int32_t cutoff = probability * 100;
  for (NSInteger i = 0; i < max; i++) {
    if (arc4random_uniform(100) < cutoff) {
      [indexes addIndex:i];
      if (insertMode) {
        max += 1;
      }
    }
  }
  return indexes;
}

#pragma mark Helpers

- (void)verifyTableStateWithHierarchy {
  NSArray <ASThrashTestSection *> *data = [ds data];
  XCTAssertEqual(data.count, tableView.numberOfSections);
  for (NSInteger i = 0; i < tableView.numberOfSections; i++) {
    XCTAssertEqual([tableView numberOfRowsInSection:i], data[i].items.count);
    XCTAssertEqual([tableView rectForHeaderInSection:i].size.height, data[i].headerHeight);
    
    for (NSInteger j = 0; j < [tableView numberOfRowsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASThrashTestItem *item = data[i].items[j];
#if USE_UIKIT_REFERENCE
      XCTAssertEqual([tableView rectForRowAtIndexPath:indexPath].size.height, item.rowHeight);
#else
      ASThrashTestNode *node = (ASThrashTestNode *)[tableView nodeForRowAtIndexPath:indexPath];
      XCTAssertEqual(node.item, item);
#endif
    }
  }
}

@end
