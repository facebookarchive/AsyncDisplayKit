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
#import <AsyncDisplayKit/ASMutableElementMap.h>
#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

@interface ASElementMap ()

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

- (NSInteger)numberOfSections
{
  return _sectionsOfItems.count;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
  return _sectionsOfItems[section].count;
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  return _sections[section].context;
}

- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element
{
  return [_elementToIndexPathMap objectForKey:element];
}

- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return (indexPath != nil) ? ASGetElementInTwoDimensionalArray(_sectionsOfItems, indexPath) : nil;
}

- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath
{
  return _supplementaryElements[supplementaryElementKind][indexPath];
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

@end
