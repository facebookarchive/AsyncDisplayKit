//
//  ASMutableElementMap.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASMutableElementMap.h"

#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

typedef NSMutableArray<NSMutableArray<ASCollectionElement *> *> ASMutableCollectionElementTwoDimensionalArray;

typedef NSMutableDictionary<NSString *, NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *> ASMutableSupplementaryElementDictionary;

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
    _supplementaryElements = [ASMutableElementMap deepMutableCopyOfElementsDictionary:supplementaryElements];
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
  ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(_sectionsOfItems, indexPaths);
}

- (void)removeSectionContextsAtIndexes:(NSIndexSet *)indexes
{
  [_sections removeObjectsAtIndexes:indexes];
}

- (void)removeAllElements
{
  [_sectionsOfItems removeAllObjects];
  [_supplementaryElements removeAllObjects];
}

- (void)removeSectionsOfItems:(NSIndexSet *)itemSections
{
  [_sectionsOfItems removeObjectsAtIndexes:itemSections];
}

- (void)removeSupplementaryElementsInSections:(NSIndexSet *)sections
{
  [_supplementaryElements enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull supplementariesForKind, BOOL * _Nonnull stop) {
    [supplementariesForKind removeObjectsForKeys:[sections as_filterIndexPathsBySection:supplementariesForKind]];
  }];
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
    NSMutableDictionary *supplementariesForKind = _supplementaryElements[kind];
    if (supplementariesForKind == nil) {
      supplementariesForKind = [NSMutableDictionary dictionary];
      _supplementaryElements[kind] = supplementariesForKind;
    }
    supplementariesForKind[indexPath] = element;
  }
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
