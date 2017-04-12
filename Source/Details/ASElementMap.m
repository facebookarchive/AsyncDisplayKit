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
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/ASMutableElementMap.h>
#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@interface ASElementMap () <ASDescriptionProvider>

@property (nonatomic, strong, readonly) NSArray<ASSection *> *sections;

// Element -> IndexPath
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, NSIndexPath *> *elementToIndexPathMap;

// The items, in a 2D array
@property (nonatomic, strong, readonly) ASCollectionElementTwoDimensionalArray *sectionsOfItems;

@property (nonatomic, strong, readonly) ASSupplementaryElementDictionary *supplementaryElements;

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
    for (NSDictionary *supplementariesForKind in [_supplementaryElements objectEnumerator]) {
      [supplementariesForKind enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *_Nonnull indexPath, ASCollectionElement * _Nonnull element, BOOL * _Nonnull stop) {
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }];
    }
  }
  return self;
}

- (NSArray<NSIndexPath *> *)itemIndexPaths
{
  return ASIndexPathsForTwoDimensionalArray(_sectionsOfItems);
}

- (NSArray<ASCollectionElement *> *)itemElements
{
  return ASElementsInTwoDimensionalArray(_sectionsOfItems);
}

- (NSInteger)numberOfSections
{
  return _sectionsOfItems.count;
}

- (NSArray<NSString *> *)supplementaryElementKinds
{
  return _supplementaryElements.allKeys;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
  if (![self sectionIndexIsValid:section assert:YES]) {
    return 0;
  }

  return _sectionsOfItems[section].count;
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  if (![self sectionIndexIsValid:section assert:NO]) {
    return nil;
  }

  return _sections[section].context;
}

- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element
{
  return [_elementToIndexPathMap objectForKey:element];
}

- (nullable NSIndexPath *)indexPathForElementIfCell:(ASCollectionElement *)element
{
  if (element.supplementaryElementKind == nil) {
    return [self indexPathForElement:element];
  } else {
    return nil;
  }
}

- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath
{
  NSInteger section, item;
  if (![self itemIndexPathIsValid:indexPath assert:NO item:&item section:&section]) {
    return nil;
  }

  return _sectionsOfItems[section][item];
}

- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath
{
  return _supplementaryElements[supplementaryElementKind][indexPath];
}

- (ASCollectionElement *)elementForLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  switch (layoutAttributes.representedElementCategory) {
    case UICollectionElementCategoryCell:
      // Cell
      return [self elementForItemAtIndexPath:layoutAttributes.indexPath];
    case UICollectionElementCategorySupplementaryView:
      // Supplementary element.
      return [self supplementaryElementOfKind:layoutAttributes.representedElementKind atIndexPath:layoutAttributes.indexPath];
    case UICollectionElementCategoryDecorationView:
      // No support for decoration views.
      return nil;
  }
}

- (NSIndexPath *)convertIndexPath:(NSIndexPath *)indexPath fromMap:(ASElementMap *)map
{
  id element = [map elementForItemAtIndexPath:indexPath];
  return [self indexPathForElement:element];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

// NSMutableCopying conformance is declared in ASMutableElementMap.h, so that most consumers of ASElementMap don't bother with it.
#pragma mark - NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone
{
  return [[ASMutableElementMap alloc] initWithSections:_sections items:_sectionsOfItems supplementaryElements:_supplementaryElements];
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id  _Nullable __unsafe_unretained [])buffer count:(NSUInteger)len
{
  return [_elementToIndexPathMap countByEnumeratingWithState:state objects:buffer count:len];
}

#pragma mark - ASDescriptionProvider

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [NSMutableArray array];
  [result addObject:@{ @"items" : _sectionsOfItems }];
  [result addObject:@{ @"supplementaryElements" : _supplementaryElements }];
  return result;
}

#pragma mark - Internal

/**
 * Fails assert + return NO if section is out of bounds.
 */
- (BOOL)sectionIndexIsValid:(NSInteger)section assert:(BOOL)assert
{
  NSInteger sectionCount = _sectionsOfItems.count;
  if (section >= sectionCount) {
    if (assert) {
      ASDisplayNodeFailAssert(@"Invalid section index %zd when there are only %zd sections!", section, sectionCount);
    }
    return NO;
  } else {
    return YES;
  }
}

/**
 * If indexPath is nil, just returns NO.
 * If indexPath is invalid, fails assertion and returns NO.
 * Otherwise returns YES and sets the item & section.
 */
- (BOOL)itemIndexPathIsValid:(NSIndexPath *)indexPath assert:(BOOL)assert item:(out NSInteger *)outItem section:(out NSInteger *)outSection
{
  if (indexPath == nil) {
    return NO;
  }

  NSInteger section = indexPath.section;
  if (![self sectionIndexIsValid:section assert:assert]) {
    return NO;
  }

  NSInteger itemCount = _sectionsOfItems[section].count;
  NSInteger item = indexPath.item;
  if (item >= itemCount) {
    if (assert) {
      ASDisplayNodeFailAssert(@"Invalid item index %zd in section %zd which only has %zd items!", item, section, itemCount);
    }
    return NO;
  }
  *outItem = item;
  *outSection = section;
  return YES;
}

@end
