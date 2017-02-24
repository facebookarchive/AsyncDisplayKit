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
#import <AsyncDisplayKit/ASMultidimensionalArrayUtils.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

typedef NSMutableArray<NSMutableArray<ASCollectionElement *> *> ASMutableCollectionElementTwoDimensionalArray;

typedef NSArray<NSArray<ASCollectionElement *> *> ASCollectionElementTwoDimensionalArray;

// ElementKind -> IndexPath -> Element
typedef NSDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> ASSupplementaryElementDictionary;
typedef NSMutableDictionary<NSString *, NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *> ASMutableSupplementaryElementDictionary;

@interface ASElementMap ()

// Element -> IndexPath
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, NSIndexPath *> *elementToIndexPathMap;

// The items, in a 2D array
@property (nonatomic, strong, readonly) ASCollectionElementTwoDimensionalArray *sectionsOfItems;

@property (nonatomic, strong, readonly) ASSupplementaryElementDictionary *supplementaryElements;

@end

@interface ASMutableElementMap ()
- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements;
@end

@implementation ASElementMap

- (instancetype)init
{
  return [self initWithSections:@[] items:@[] supplementaryElements:@{}];
}

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements
{
  if (self = [super init]) {
    _sections = [sections copy];
    _sectionsOfItems = [[NSArray alloc] initWithArray:items copyItems:YES];
    _supplementaryElements = [[NSDictionary alloc] initWithDictionary:supplementaryElements copyItems:YES];

    // Setup our index path map
    _elementToIndexPathMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableCopyIn];
    NSInteger s = 0;
    for (NSArray *section in _sectionsOfItems) {
      NSInteger i = 0;
      for (ASCollectionElement *element in section) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
        [_elementToIndexPathMap setObject:indexPath forKey:element];
        i++;
      }
      s++;
    }
    for (NSDictionary *supsOfKind in [_supplementaryElements objectEnumerator]) {
      [supsOfKind enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *_Nonnull indexPath, ASCollectionElement * _Nonnull element, BOOL * _Nonnull stop) {
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }];
    }
  }
  return self;
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
  for (NSArray *section in _sectionsOfItems) {
    for (ASCollectionElement *element in section) {
      NSIndexPath *indexPath = [self indexPathForElement:element];
      block(indexPath, element, &stop);
      if (stop) {
        return;
      }
    }
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

- (id)mutableCopyWithZone:(NSZone *)zone
{
  return [[ASMutableElementMap alloc] initWithSections:_sections items:_sectionsOfItems supplementaryElements:_supplementaryElements];
}

#pragma mark - Helpers

+ (ASMutableSupplementaryElementDictionary *)deepMutableCopyOfElementsDictionary:(ASSupplementaryElementDictionary *)originalDict
{
  NSMutableDictionary *deepCopy = [NSMutableDictionary dictionaryWithCapacity:originalDict.count];
  [originalDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull obj, BOOL * _Nonnull stop) {
    deepCopy[key] = [obj mutableCopy];
  }];

  return deepCopy;
}
@end

@implementation ASMutableElementMap {
  ASMutableSupplementaryElementDictionary *_supplementaryElements;
  NSMutableArray<ASSection *> *_sections;
  ASMutableCollectionElementTwoDimensionalArray *_sectionsOfItems;
}

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements
{
  if (self = [super init]) {
    _sections = [sections mutableCopy];
    _sectionsOfItems = (id)ASTwoDimensionalArrayDeepMutableCopy(items);
    _supplementaryElements = [ASElementMap deepMutableCopyOfElementsDictionary:supplementaryElements];
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[ASElementMap alloc] initWithSections:_sections items:_sectionsOfItems supplementaryElements:_supplementaryElements];
}

- (void)removeAllSectionContexts
{
  [_sections removeAllObjects];
}

- (void)insertSection:(ASSection *)section atIndex:(NSInteger)index
{
  [_sections insertObject:section atIndex:index];
}

- (void)removeItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  indexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_sectionsOfItems, indexPaths);
}

- (void)removeSectionContextsAtIndexes:(NSIndexSet *)indexes
{
  [_sections removeObjectsAtIndexes:indexes];
}

- (void)removeAllElements
{
  [_sectionsOfItems removeAllObjects];
}

- (void)removeElementsOfKind:(NSString *)kind inSections:(NSIndexSet *)sections
{
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    // Items
    [_sectionsOfItems removeObjectsAtIndexes:sections];
  } else {
    // Supplementaries
    NSMutableDictionary *supsForKind = _supplementaryElements[kind];
    [supsForKind removeObjectsForKeys:[sections as_filterIndexPathsBySection:supsForKind]];
  }
}

- (void)insertEmptySectionsOfItemsAtIndexes:(NSIndexSet *)sections
{
  [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [_sectionsOfItems insertObject:[NSMutableArray array] atIndex:idx];
  }];
}

- (void)insertElement:(ASCollectionElement *)element atIndexPath:(NSIndexPath *)indexPath
{
  NSString *kind = element.supplementaryElementKind;
  if (kind == nil) {
    [_sectionsOfItems[indexPath.section] insertObject:element atIndex:indexPath.item];
  } else {
    _supplementaryElements[kind][indexPath] = element;
  }
}

@end
