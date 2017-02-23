//
//  ASElementMap.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/22/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASElementMap.h"
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/ASMultidimensionalArrayUtils.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

@interface ASElementMap ()

// Element -> IndexPath
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, NSIndexPath *> *elementToIndexPathMap;

// The items, in a 2D array
@property (nonatomic, strong) NSArray<NSArray<ASCollectionElement *> *> *sectionsOfItems;

// ElementKind -> IndexPath -> Element
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> *supplementaryElements;

@end

@implementation ASElementMap

+ (ASElementMap *)emptyElementMap __const
{
  static ASElementMap *emptyMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    emptyMap = [[ASElementMap alloc] init];
    emptyMap->_elementToIndexPathMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];
    emptyMap->_sectionsOfItems = @[];
    emptyMap->_supplementaryElements = @{};
  });
  return emptyMap;
}

- (NSInteger)numberOfSections
{
	return _sectionsOfItems.count;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
	return _sectionsOfItems[section].count;
}

- (NSArray<NSString *> *)supplementaryElementKinds
{
  return [_supplementaryElements allKeys] ?: @[];
}

- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element
{
	return [_elementToIndexPathMap objectForKey:element];
}

- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ASGetElementInTwoDimensionalArray(_sectionsOfItems, indexPath);
}

- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath
{
	return _supplementaryElements[supplementaryElementKind][indexPath];
}

- (void)enumerateUsingBlock:(void(^)(NSIndexPath *indexPath, ASCollectionElement *element, BOOL *stop))block
{
	__block BOOL stop = NO;

	// Do items first
	NSInteger s = 0;
	for (NSArray *section in _sectionsOfItems) {
		NSInteger i = 0;
		for (ASCollectionElement *element in section) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
			block(indexPath, element, &stop);
			if (stop) {
				return;
			}
			i++;
		}
		s++;
	}

	// Then supplementaries
	[_supplementaryElements enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull kind, NSDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull elementsOfKind, BOOL * _Nonnull stop0) {
		[elementsOfKind enumerateKeysAndObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, ASCollectionElement * _Nonnull element, BOOL * _Nonnull stop1) {
			block(indexPath, element, &stop);
			if (stop) {
				*stop1 = YES;
			}
		}];
		if (stop) {
			*stop0 = YES;
		}
	}];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

@implementation ASElementMap (Operations)

- (instancetype)initWithPreviousMap:(ASElementMap *)previousMap changeSet:(_ASHierarchyChangeSet *)changeSet dataController:(ASDataController *)dataController environment:(id<ASTraitEnvironment>)environment
{
  if (self = [super init]) {
    id<ASDataControllerSource> dataSource = dataController.dataSource;

    _elementToIndexPathMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];
    NSMutableArray<NSMutableArray<ASCollectionElement *> *> *sections = ASMultidimensionalArrayDeepMutableCopy(previousMap.sectionsOfItems);
    NSMutableDictionary<NSString *, NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *> *mutableSupplementaries = [NSMutableDictionary dictionaryWithCapacity:previousMap.supplementaryElements.count];
    [previousMap.supplementaryElements enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull obj, BOOL * _Nonnull stop) {
      mutableSupplementaries[key] = [obj mutableCopy];
    }];

    NSInteger newSectionCount = [dataSource numberOfSectionsInDataController:dataController];
    NSIndexSet *sectionsToInsert;

    // Delete sections
    if (changeSet.includesReloadData) {
      [sections removeAllObjects];
      [mutableSupplementaries removeAllObjects];
      sectionsToInsert = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newSectionCount)];
    } else {
      sectionsToInsert = changeSet.insertedSections;
      NSIndexSet *deletedSections = changeSet.deletedSections;
      [sections removeObjectsAtIndexes:deletedSections];
      [mutableSupplementaries enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull kind, NSMutableDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull supps, BOOL * _Nonnull stop) {
        [supps removeObjectsForKeys:[deletedSections as_filterIndexPathsBySection:supps]];
      }];

    }

    // Insert sections
    [sectionsToInsert enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [sections insertObject:[NSMutableArray array] atIndex:idx];
    }];

    // Insert elements

    // Get the items
    NSInteger sectionCount = [dataSource numberOfSectionsInDataController:dataController];
    for (NSInteger s = 0; s < sectionCount; s++) {
      NSInteger itemCount = [dataSource dataController:dataController rowsInSection:s];
      NSMutableArray<ASCollectionElement *> *items = [NSMutableArray arrayWithCapacity:itemCount];
      for (NSInteger i = 0; i < itemCount; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
        ASCollectionElement *element = [ASElementMap elementFromDataController:dataController ofKind:ASDataControllerRowNodeKind indexPath:indexPath environment:environment];
        items[i] = element;
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }
      sections[s] = [items copy];
    }
    _sectionsOfItems = [[NSArray alloc] initWithArray:sections copyItems:YES];

    // Get the supplementaries
    NSIndexSet *allSections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
    NSArray<NSString *> *supplementaryKinds = [dataSource dataController:dataController supplementaryNodeKindsInSections:allSections];

    for (NSString *kind in supplementaryKinds) {
      NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *elementsOfKind = [NSMutableDictionary dictionary];
      NSArray *indexPaths = [ASElementMap indexPathsForSupplementaryElementOfKind:kind inDataSource:nil sectionCount:sectionCount];
      for (NSIndexPath *indexPath in indexPaths) {
        ASCollectionElement *element = [ASElementMap elementFromDataController:dataController ofKind:kind indexPath:indexPath environment:environment];
        elementsOfKind[indexPath] = element;
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }
      mutableSupplementaries[kind] = [elementsOfKind copy];
    }
    _supplementaryElements = [mutableSupplementaries copy];
  }
  return self;
}

- (instancetype)initFromDataSource:(id<ASDataControllerSource>)dataSource
{
  static _ASHierarchyChangeSet *emptyChangeset;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    emptyChangeset = [[_ASHierarchyChangeSet alloc] init];
    [emptyChangeset reloadData];
  });
  return [self initWithPreviousMap:[ASElementMap emptyElementMap] changeSet:emptyChangeset dataSource:dataSource];
}

#pragma mark - Helpers

/**
 * Get a new ASCollectionElement of the given kind and index path from the data source.
 */
+ (ASCollectionElement *)elementFromDataController:(ASDataController *)dataController ofKind:(NSString *)kind indexPath:(NSIndexPath *)indexPath environment:(id<ASTraitEnvironment>)environment
{
  ASCollectionElement *element;
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    ASCellNodeBlock nodeBlock = [dataSource dataController:nil nodeBlockAtIndexPath:indexPath];
    ASSizeRange sizeRange = [dataSource dataController:nil constrainedSizeForNodeAtIndexPath:indexPath];
    element = [[ASCollectionElement alloc] initWithNodeBlock:nodeBlock supplementaryElementKind:nil constrainedSize:sizeRange environment:environment];
  } else {
    ASCellNodeBlock nodeBlock = [dataSource dataController:nil supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
    ASSizeRange sizeRange = [dataSource dataController:nil constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
    element = [[ASCollectionElement alloc] initWithNodeBlock:nodeBlock supplementaryElementKind:kind constrainedSize:sizeRange environment:environment];
  }

  return element;
}

/**
 * Get all the index paths for supplementary nodes of the given kind from the data source.
 *
 * Currently our supplementary node API is built like an item API, where we get "item counts" per section.
 * But supplementary nodes don't work that way. You can have holes, you can have NO item index, etc.
 *
 * In the future we should update the data source API to DIRECTLY ask the user for an array of index paths.
 * For the time being, we'll use this method to bridge the gap to the rest of infra.
 */
+ (NSArray<NSIndexPath *> *)indexPathsForSupplementaryElementOfKind:(NSString *)kind inDataSource:(id<ASDataControllerSource>)dataSource sectionCount:(NSInteger)sectionCount
{
  NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
  for (NSInteger s = 0; s < sectionCount; s++) {
    NSInteger suppCount = [dataSource dataController:nil supplementaryNodesOfKind:kind inSection:sectionCount];
    for (NSInteger i = 0; i < suppCount; i++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
      [indexPaths addObject:indexPath];
    }
  }
  return indexPaths;
}
@end
