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
#define kMinimumItemCount 5
#define kMinimumSectionCount 3
#define kFickleness 0.1

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

static volatile int32_t ASThrashTestItemNextID = 1;
@interface ASThrashTestItem: NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSInteger itemID;

- (CGFloat)rowHeight;
@end

@implementation ASThrashTestItem

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _itemID = OSAtomicIncrement32(&ASThrashTestItemNextID);
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    _itemID = [aDecoder decodeIntegerForKey:@"itemID"];
    NSAssert(_itemID > 0, @"Failed to decode %@", self);
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeInteger:_itemID forKey:@"itemID"];
}

+ (NSMutableArray <ASThrashTestItem *> *)itemsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestItem alloc] init]];
  }
  return result;
}

- (CGFloat)rowHeight {
  return (self.itemID % 400) ?: 44;
}


- (NSString *)description {
  return [NSString stringWithFormat:@"<Item %lu>", (unsigned long)_itemID];
}

@end

@interface ASThrashTestSection: NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, strong, readonly) NSMutableArray *items;
@property (nonatomic, readonly) NSInteger sectionID;

- (CGFloat)headerHeight;
@end

static volatile int32_t ASThrashTestSectionNextID = 1;
@implementation ASThrashTestSection

/// Create an array of sections with the given count
+ (NSMutableArray <ASThrashTestSection *> *)sectionsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestSection alloc] initWithCount:kInitialItemCount]];
  }
  return result;
}

- (instancetype)initWithCount:(NSInteger)count {
  self = [super init];
  if (self != nil) {
    _sectionID = OSAtomicIncrement32(&ASThrashTestSectionNextID);
    _items = [ASThrashTestItem itemsWithCount:count];
  }
  return self;
}

- (instancetype)init {
  return [self initWithCount:0];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    _items = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"items"];
    _sectionID = [aDecoder decodeIntegerForKey:@"sectionID"];
    NSAssert(_sectionID > 0, @"Failed to decode %@", self);
  }
  return self;
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_items forKey:@"items"];
  [aCoder encodeInteger:_sectionID forKey:@"sectionID"];
}

- (CGFloat)headerHeight {
  return self.sectionID % 400 ?: 44;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<Section %lu: itemCount=%lu>", (unsigned long)_sectionID, (unsigned long)self.items.count];
}

- (id)copyWithZone:(NSZone *)zone {
  ASThrashTestSection *copy = [[ASThrashTestSection alloc] init];
  copy->_sectionID = _sectionID;
  copy->_items = [_items mutableCopy];
  return copy;
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[ASThrashTestSection class]]) {
    return [(ASThrashTestSection *)object sectionID] == _sectionID;
  } else {
    return NO;
  }
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

/// `insertMode` means that for each index selected, the max goes up by one.
+ (NSMutableIndexSet *)randomIndexesLessThan:(NSInteger)max probability:(float)probability insertMode:(BOOL)insertMode {
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

@end

static NSInteger ASThrashUpdateCurrentSerializationVersion = 1;

@interface ASThrashUpdate : NSObject <NSSecureCoding>
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *oldData;
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *data;
@property (nonatomic, strong, readonly) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableIndexSet *replacedSectionIndexes;
/// The sections used to replace the replaced sections.
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *replacingSections;
@property (nonatomic, strong, readonly) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *insertedSections;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *deletedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *replacedItemIndexes;
/// The items used to replace the replaced items.
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *replacingItems;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *insertedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *insertedItems;

/// NOTE: `data` will be modified
- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data;

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64;
- (NSString *)base64Representation;
@end

@implementation ASThrashUpdate

- (instancetype)initWithData:(NSMutableArray<ASThrashTestSection *> *)data {
  self = [super init];
  if (self != nil) {
    _oldData = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
    
    _deletedItemIndexes = [NSMutableArray array];
    _replacedItemIndexes = [NSMutableArray array];
    _insertedItemIndexes = [NSMutableArray array];
    
    // Randomly reload some items
    for (ASThrashTestSection *section in data) {
      NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO];
      NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
      [section.items replaceObjectsAtIndexes:indexes withObjects:newItems];
      [_replacedItemIndexes addObject:indexes];
    }
    
    // Randomly replace some sections
    _replacedSectionIndexes = [NSIndexSet randomIndexesLessThan:data.count probability:kFickleness insertMode:NO];
    _replacingSections = [ASThrashTestSection sectionsWithCount:_replacedSectionIndexes.count];
    [data replaceObjectsAtIndexes:_replacedSectionIndexes withObjects:_replacingSections];
    
    // Randomly delete some items
    [data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
      if (section.items.count >= kMinimumItemCount) {
        NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO];
        
        /// Cannot reload & delete the same item.
        [indexes removeIndexes:_replacedItemIndexes[idx]];
        
        [section.items removeObjectsAtIndexes:indexes];
        [_deletedItemIndexes addObject:indexes];
      } else {
        [_deletedItemIndexes addObject:[NSMutableIndexSet indexSet]];
      }
    }];
    
    // Randomly delete some sections
    if (data.count >= kMinimumSectionCount) {
      _deletedSectionIndexes = [NSIndexSet randomIndexesLessThan:data.count probability:kFickleness insertMode:NO];
    } else {
      _deletedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    // Cannot replace & delete the same section.
    [_deletedSectionIndexes removeIndexes:_replacedSectionIndexes];
    
    // Cannot delete/replace item in deleted/replaced section
    [_deletedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    [_replacedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    [data removeObjectsAtIndexes:_deletedSectionIndexes];
    
    // Randomly insert some sections
    _insertedSectionIndexes = [NSIndexSet randomIndexesLessThan:(data.count + 1) probability:kFickleness insertMode:YES];
    _insertedSections = [ASThrashTestSection sectionsWithCount:_insertedSectionIndexes.count];
    [data insertObjects:_insertedSections atIndexes:_insertedSectionIndexes];
    
    // Randomly insert some items
    for (ASThrashTestSection *section in data) {
      // Only insert items into the old sections – not replaced/inserted sections.
      if ([_oldData containsObject:section]) {
        NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:(section.items.count + 1) probability:kFickleness insertMode:YES];
        NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
        [section.items insertObjects:newItems atIndexes:indexes];
        [_insertedItemIndexes addObject:indexes];
      } else {
        [_insertedItemIndexes addObject:[NSMutableIndexSet indexSet]];
      }
    }
  }
  return self;
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64 {
  return [NSKeyedUnarchiver unarchiveObjectWithData:[[NSData alloc] initWithBase64EncodedString:base64 options:kNilOptions]];
}

- (NSString *)base64Representation {
  return [[NSKeyedArchiver archivedDataWithRootObject:self] base64EncodedStringWithOptions:kNilOptions];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  NSDictionary *dict = [self dictionaryWithValuesForKeys:@[
     @"oldData",
     @"deletedSectionIndexes",
     @"replacedSectionIndexes",
     @"replacingSections",
     @"insertedSectionIndexes",
     @"insertedSections",
     @"deletedItemIndexes",
     @"replacedItemIndexes",
     @"replacingItems",
     @"insertedItemIndexes",
     @"insertedItems"
  ]];
  [aCoder encodeObject:dict forKey:@"_dict"];
  [aCoder encodeInteger:ASThrashUpdateCurrentSerializationVersion forKey:@"_version"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    NSAssert(ASThrashUpdateCurrentSerializationVersion == [aDecoder decodeIntegerForKey:@"_version"], @"This thrash update was archived from a different version and can't be read. Sorry.");
    NSDictionary *dict = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"_dict"];
    [self setValuesForKeysWithDictionary:dict];
  }
  return self;
}

- (void)applyToTableView:(UITableView *)tableView {
  [tableView beginUpdates];
  
  [tableView insertSections:_insertedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView deleteSections:_deletedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView reloadSections:_replacedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [_insertedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:idx];
    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [_deletedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [_replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  @try {
    [tableView endUpdates];
  } @catch (NSException *exception) {
    NSLog(@"Rejected update base64: %@", self.base64Representation);
    @throw exception;
  }
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
  ASThrashUpdate *currentUpdate;
}

- (void)setUp {
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

- (void)testSpecificThrashing {
  NSURL *caseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ASThrashTestRecordedCase" withExtension:nil subdirectory:@"TestResources"];
  NSString *base64 = [NSString stringWithContentsOfURL:caseURL encoding:NSUTF8StringEncoding error:nil];
  
  ASThrashUpdate *update = [ASThrashUpdate thrashUpdateWithBase64String:base64];
  if (update == nil) {
    return;
  }
  
  currentUpdate = update;
  
  LOG(@"Deleted items: %@\nDeleted sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@", ASThrashArrayDescription(deletedItems), deletedSections, ASThrashArrayDescription(replacedItems), replacedSections, ASThrashArrayDescription(insertedItems), insertedSections, ASThrashArrayDescription(ds.data));
  
  [update applyToTableView:tableView];
#if !USE_UIKIT_REFERENCE
  XCTAssertNoThrow([tableView waitUntilAllUpdatesAreCommitted], @"Update assertion failure: %@", update);
#endif
  [self verifyTableStateWithHierarchy];
  currentUpdate = nil;
}

- (void)testThrashingWildly {
  for (NSInteger i = 0; i < 100; i++) {
    [self setUp];
    [self _testThrashingWildly];
    [self tearDown];
  }
}

- (void)_testThrashingWildly {
  LOG(@"\n*******\nNext Iteration\n*******\nOld data: %@", ASThrashArrayDescription(ds.data));
  
  ASThrashUpdate *update = [[ASThrashUpdate alloc] initWithData:ds.data];
  currentUpdate = update;
  
  LOG(@"Deleted items: %@\nDeleted sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@", ASThrashArrayDescription(deletedItems), deletedSections, ASThrashArrayDescription(replacedItems), replacedSections, ASThrashArrayDescription(insertedItems), insertedSections, ASThrashArrayDescription(ds.data));
  
  [update applyToTableView:tableView];
#if !USE_UIKIT_REFERENCE
  XCTAssertNoThrow([tableView waitUntilAllUpdatesAreCommitted], @"Update assertion failure: %@", update);
#endif
  [self verifyTableStateWithHierarchy];
  currentUpdate = nil;
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
