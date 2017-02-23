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

@interface ASElementMap ()

// Element -> IndexPath
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, NSIndexPath *> *elementToIndexPathMap;

// The items, in a 2D array
@property (nonatomic, strong) NSArray<NSArray<ASCollectionElement *> *> *sectionsOfItems;

// ElementKind -> IndexPath -> Element
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> *supplementaryElements;
@end

@implementation ASElementMap

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
	return [_supplementaryElements allKeys];
}

- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element
{
	return [_elementToIndexPathMap objectForKey:element];
}

- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return _sectionsOfItems[indexPath.section][indexPath.item];
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

- (instancetype)initFromDataSource:(id<ASDataControllerSource>)dataSource
{
  if (self = [super init]) {
    id fakeDataController = nil;
    id<ASTraitEnvironment> environment = nil;

    _elementToIndexPathMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];

    // Get the items
    NSInteger sectionCount = [dataSource numberOfSectionsInDataController:fakeDataController];
    NSMutableArray<NSArray<ASCollectionElement *> *> *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    for (NSInteger s = 0; s < sectionCount; s++) {
      NSInteger itemCount = [dataSource dataController:fakeDataController rowsInSection:s];
      NSMutableArray<ASCollectionElement *> *items = [NSMutableArray arrayWithCapacity:itemCount];
      for (NSInteger i = 0; i < itemCount; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
        ASCollectionElement *element = [ASElementMap elementFromDataSource:dataSource ofKind:ASDataControllerRowNodeKind indexPath:indexPath environment:environment];
        items[i] = element;
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }
      sections[s] = [items copy];
    }
    _sectionsOfItems = [sections copy];

    // Get the supplementaries
    NSIndexSet *allSections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
    NSArray<NSString *> *supplementaryKinds = [dataSource dataController:fakeDataController supplementaryNodeKindsInSections:allSections];
    NSMutableDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> *mutableSupplementaries = [NSMutableDictionary dictionaryWithCapacity:supplementaryKinds.count];
    for (NSString *kind in supplementaryKinds) {
      NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *elementsOfKind = [NSMutableDictionary dictionary];
      NSArray *indexPaths = [ASElementMap indexPathsForSupplementaryElementOfKind:kind inDataSource:nil sectionCount:sectionCount];
      for (NSIndexPath *indexPath in indexPaths) {
        ASCollectionElement *element = [ASElementMap elementFromDataSource:dataSource ofKind:kind indexPath:indexPath environment:environment];
        elementsOfKind[indexPath] = element;
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }
      mutableSupplementaries[kind] = [elementsOfKind copy];
    }
    _supplementaryElements = [mutableSupplementaries copy];
  }
  return self;
}

#pragma mark - Helpers

/**
 * Get a new ASCollectionElement of the given kind and index path from the data source.
 */
+ (ASCollectionElement *)elementFromDataSource:(id<ASDataControllerSource>)dataSource ofKind:(NSString *)kind indexPath:(NSIndexPath *)indexPath environment:(id<ASTraitEnvironment>)environment
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
