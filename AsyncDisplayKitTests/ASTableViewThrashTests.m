//
//  ASTableViewThrashTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 6/21/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

@import XCTest;
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASTableViewInternal.h"
#import "ASTableView+Undeprecated.h"


// Set to 1 to use UITableView and see if the issue still exists.
#define USE_UIKIT_REFERENCE 0

#if USE_UIKIT_REFERENCE
#define TableView UITableView
#define kCellReuseID @"ASThrashTestCellReuseID"
#else
#define TableView ASTableView
#endif

#define kInitialSectionCount 10
#define kInitialItemCount 10
#define kMinimumItemCount 5
#define kMinimumSectionCount 3
#define kFickleness 0.1
#define kThrashingIterationCount 100

static NSString *ASThrashArrayDescription(NSArray *array) {
  NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
  NSInteger i = 0;
  for (id obj in array) {
    [str appendFormat:@"\t[%ld]: \"%@\",\n", (long)i, obj];
    i += 1;
  }
  [str appendString:@")"];
  return str;
}

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
  return [NSString stringWithFormat:@"<Section %lu: itemCount=%lu, items=%@>", (unsigned long)_sectionID, (unsigned long)self.items.count, ASThrashArrayDescription(self.items)];
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

@property (nonatomic, strong, readonly) UIWindow *window;
@property (nonatomic, strong, readonly) TableView *tableView;
@property (nonatomic, strong) NSArray <ASThrashTestSection *> *data;
@end


@implementation ASThrashDataSource

- (instancetype)initWithData:(NSArray <ASThrashTestSection *> *)data {
  self = [super init];
  if (self != nil) {
    _data = [[NSArray alloc] initWithArray:data copyItems:YES];
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _tableView = [[TableView alloc] initWithFrame:_window.bounds style:UITableViewStylePlain];
    [_window addSubview:_tableView];
#if USE_UIKIT_REFERENCE
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseID];
#else
    _tableView.asyncDelegate = self;
    _tableView.asyncDataSource = self;
    [_tableView reloadDataImmediately];
#endif
    [_tableView layoutIfNeeded];
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
@property (nonatomic, strong, readonly) NSArray<ASThrashTestSection *> *oldData;
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
@property (nonatomic, strong, readonly) NSMutableArray<NSArray <ASThrashTestItem *> *> *replacingItems;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *insertedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<NSArray <ASThrashTestItem *> *> *insertedItems;

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data;

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64;
- (NSString *)base64Representation;
@end

@implementation ASThrashUpdate

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data {
  self = [super init];
  if (self != nil) {
    _data = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
    _oldData = [[NSArray alloc] initWithArray:data copyItems:YES];
    
    _deletedItemIndexes = [NSMutableArray array];
    _replacedItemIndexes = [NSMutableArray array];
    _insertedItemIndexes = [NSMutableArray array];
    _replacingItems = [NSMutableArray array];
    _insertedItems = [NSMutableArray array];
    
    // Randomly reload some items
    for (ASThrashTestSection *section in _data) {
      NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO];
      NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
      [section.items replaceObjectsAtIndexes:indexes withObjects:newItems];
      [_replacingItems addObject:newItems];
      [_replacedItemIndexes addObject:indexes];
    }
    
    // Randomly replace some sections
    _replacedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO];
    _replacingSections = [ASThrashTestSection sectionsWithCount:_replacedSectionIndexes.count];
    [_data replaceObjectsAtIndexes:_replacedSectionIndexes withObjects:_replacingSections];
    
    // Randomly delete some items
    [_data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
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
    if (_data.count >= kMinimumSectionCount) {
      _deletedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO];
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
    [_data removeObjectsAtIndexes:_deletedSectionIndexes];
    
    // Randomly insert some sections
    _insertedSectionIndexes = [NSIndexSet randomIndexesLessThan:(_data.count + 1) probability:kFickleness insertMode:YES];
    _insertedSections = [ASThrashTestSection sectionsWithCount:_insertedSectionIndexes.count];
    [_data insertObjects:_insertedSections atIndexes:_insertedSectionIndexes];
    
    // Randomly insert some items
    for (ASThrashTestSection *section in _data) {
      // Only insert items into the old sections – not replaced/inserted sections.
      if ([_oldData containsObject:section]) {
        NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:(section.items.count + 1) probability:kFickleness insertMode:YES];
        NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
        [section.items insertObjects:newItems atIndexes:indexes];
        [_insertedItems addObject:newItems];
        [_insertedItemIndexes addObject:indexes];
      } else {
        [_insertedItems addObject:@[]];
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
   @"data",
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

- (NSString *)description {
  return [NSString stringWithFormat:@"<ASThrashUpdate %p:\nOld data: %@\nDeleted items: %@\nDeleted sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@>", self, ASThrashArrayDescription(_oldData), ASThrashArrayDescription(_deletedItemIndexes), _deletedSectionIndexes, ASThrashArrayDescription(_replacedItemIndexes), _replacedSectionIndexes, ASThrashArrayDescription(_insertedItemIndexes), _insertedSectionIndexes, ASThrashArrayDescription(_data)];
}

- (NSString *)logFriendlyBase64Representation {
  return [NSString stringWithFormat:@"\n\n**********\nBase64 Representation:\n**********\n%@\n**********\nEnd Base64 Representation\n**********", self.base64Representation];
}

@end

@interface ASTableViewThrashTests: XCTestCase
@end

@implementation ASTableViewThrashTests {
  // The current update, which will be logged in case of a failure.
  ASThrashUpdate *_update;
  BOOL _failed;
}

#pragma mark Overrides

- (void)tearDown {
  if (_failed && _update != nil) {
    NSLog(@"Failed update %@: %@", _update, _update.logFriendlyBase64Representation);
  }
  _failed = NO;
  _update = nil;
}

// NOTE: Despite the documentation, this is not always called if an exception is caught.
- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected {
  _failed = YES;
  [super recordFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
}

#pragma mark Test Methods

// Disabled temporarily due to issue where cell nodes are not marked invisible before deallocation.
- (void)DISABLED_testInitialDataRead {
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
  [self verifyDataSource:ds];
}

/// Replays the Base64 representation of an ASThrashUpdate from "ASThrashTestRecordedCase" file
- (void)DISABLED_testRecordedThrashCase {
  NSURL *caseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ASThrashTestRecordedCase" withExtension:nil subdirectory:@"TestResources"];
  NSString *base64 = [NSString stringWithContentsOfURL:caseURL encoding:NSUTF8StringEncoding error:NULL];
  
  _update = [ASThrashUpdate thrashUpdateWithBase64String:base64];
  if (_update == nil) {
    return;
  }
  
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:_update.oldData];
  ds.tableView.test_enableSuperUpdateCallLogging = YES;
  [self applyUpdate:_update toDataSource:ds];
  [self verifyDataSource:ds];
}

// Disabled temporarily due to issue where cell nodes are not marked invisible before deallocation.
- (void)DISABLED_testThrashingWildly {
  for (NSInteger i = 0; i < kThrashingIterationCount; i++) {
    [self setUp];
    ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
    _update = [[ASThrashUpdate alloc] initWithData:ds.data];
    
    [self applyUpdate:_update toDataSource:ds];
    [self verifyDataSource:ds];
    [self tearDown];
  }
}

#pragma mark Helpers

- (void)applyUpdate:(ASThrashUpdate *)update toDataSource:(ASThrashDataSource *)dataSource {
  TableView *tableView = dataSource.tableView;
  
  [tableView beginUpdates];
  dataSource.data = update.data;
  
  [tableView insertSections:update.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView deleteSections:update.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView reloadSections:update.replacedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [update.insertedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:idx];
    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.deletedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  @try {
    [tableView endUpdates];
#if !USE_UIKIT_REFERENCE
    [tableView waitUntilAllUpdatesAreCommitted];
#endif
  } @catch (NSException *exception) {
    _failed = YES;
    @throw exception;
  }
}

- (void)verifyDataSource:(ASThrashDataSource *)ds {
  TableView *tableView = ds.tableView;
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
      XCTAssertEqualObjects(node.item, item, @"Wrong node at index path %@", indexPath);
#endif
    }
  }
}

@end
