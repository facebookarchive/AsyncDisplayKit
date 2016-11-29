//
//  ASCollectionDataInternal.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 11/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASCollectionDataInternal.h"
#import "ASDimension.h"
#import "ASEqualityHashHelpers.h"

static ASSectionIdentifier const ASDefaultSectionIdentifier = @"ASDefaultSectionIdentifier";

std::vector<NSInteger> ASItemCountsFromData(ASCollectionData * data)
{
  std::vector<NSInteger> result;
  for (id<ASCollectionSection> s in data.mutableSections) {
    result.push_back(s.mutableItems.count);
  }
	return result;
}

@implementation ASCollectionItemImpl
@synthesize identifier = _identifier;
@synthesize nodeBlock = _nodeBlock;

- (instancetype)initWithIdentifier:(ASItemIdentifier)identifier nodeBlock:(ASCellNodeBlock)nodeBlock
{
  self = [super init];
  if (self != nil) {
    _identifier = identifier;
    _nodeBlock = nodeBlock;
  }
  return self;
}

- (ASCellNodeBlock)nodeBlock
{
  ASCellNodeBlock result = _nodeBlock;
  _nodeBlock = nil;
  return result;
}

- (BOOL)isEqual:(id)object
{
  if ([object isKindOfClass:[ASCollectionItemImpl class]] == NO) {
    return NO;
  }
  return [_identifier isEqualToString:[object identifier]];
}

- (NSUInteger)hash
{
  return _identifier.hash;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray <NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *array = [NSMutableArray array];
  [array addObject:@{ @"identifier" : _identifier }];
  return array;
}

@end

@implementation ASCollectionSectionImpl
@synthesize mutableItems = _mutableItems;
@synthesize identifier = _identifier;

- (instancetype)initWithIdentifier:(ASSectionIdentifier)identifier
{
  self = [super init];
  if (self != nil) {
    _identifier = identifier;
    _mutableItems = [NSMutableArray array];
    _supplementaryElements = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSArray *)itemsInternal
{
  return _mutableItems;
}

- (BOOL)isEqual:(id)object
{
  if ([object isKindOfClass:[ASCollectionSectionImpl class]] == NO) {
    return NO;
  }
  ASCollectionSectionImpl *otherSection = (ASCollectionSectionImpl *)object;
  return [_identifier isEqualToString:otherSection.identifier]
    && [_supplementaryElements isEqualToDictionary:otherSection.supplementaryElements];
}

- (NSUInteger)hash
{
  return ASHashCombine((uint64_t)_identifier.hash, (uint64_t)_supplementaryElements.hash);
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[self.class alloc] initWithIdentifier:_identifier];
}

- (void)setSupplementaryElement:(ASCollectionItemImpl *)item ofKind:(ASSupplementaryElementKind)kind atIndex:(NSInteger)index
{
  NSMutableDictionary<NSNumber *, ASCollectionItemImpl *> *dict = _supplementaryElements[kind];
  if (dict == nil) {
    dict = [NSMutableDictionary dictionary];
    _supplementaryElements[kind] = dict;
  }
  ASDisplayNodeAssertNil(dict[@(index)], @"Supplementary element of kind %@ already exists at index %td. Identifier: %@", kind, index, dict[@(index)].identifier);
  dict[@(index)] = item;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray <NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *array = [NSMutableArray array];
  [array addObject:@{ @"identifier" : _identifier }];
  [array addObject:@{ @"items" : _mutableItems }];
  if (_supplementaryElements.count > 0) {
    [array addObject:@{ @"supplementaries" : _supplementaryElements }];
  }
  return array;
}

@end

@implementation ASCollectionData {
  ASCollectionSectionImpl *_currentSection;

  NSMutableDictionary<ASItemIdentifier, ASCollectionItemImpl *> *_itemsDict;
  NSMutableDictionary<ASSectionIdentifier, ASCollectionSectionImpl *> *_sectionsDict;

  // We could have used NSMutableSet for these, but copying the dictionary is probably faster than
  // creating an array of all keys, then creating a set of those, and then creating an array from the set
  // during the copy.
  NSMutableDictionary<ASItemIdentifier, ASCollectionItemImpl *> *_usedItems;
  NSMutableDictionary<ASSectionIdentifier, ASCollectionSectionImpl *> *_usedSections;

  NSMutableSet *_supplementaryElementKinds;
  BOOL _completed;
}

- (instancetype)initWithReusableContentFromCompletedData:(ASCollectionData *)data
{
  self = [super init];
  if (self != nil) {
    _usedItems = [NSMutableDictionary dictionary];
    _usedSections = [NSMutableDictionary dictionary];
    _mutableSections = [NSMutableArray array];
    _supplementaryElementKinds = [NSMutableSet set];
    
    if (data != nil) {
      ASDisplayNodeAssert(data->_completed, @"You must pass a completed collection data.");
      _itemsDict = data->_usedItems;
      _sectionsDict = [[NSMutableDictionary alloc] initWithDictionary:data->_usedSections copyItems:YES];
    } else {
      _itemsDict = [NSMutableDictionary dictionary];
      _sectionsDict = [NSMutableDictionary dictionary];
    }
  }
  return self;
}

- (instancetype)init
{
  return [self initWithReusableContentFromCompletedData:nil];
}

#pragma mark - Convenience Builders (Public)

- (void)addSectionWithIdentifier:(ASSectionIdentifier)identifier block:(void (^)(ASCollectionData * _Nonnull))block
{
  if (_currentSection != nil) {
    ASDisplayNodeFailAssert(@"Call to %@ must not be inside an addSection: block.", NSStringFromSelector(_cmd));
    return;
  }

  _currentSection = (ASCollectionSectionImpl *)[self sectionWithIdentifier:identifier];
  [_mutableSections addObject:_currentSection];
  block(self);
  _currentSection = nil;
}

- (void)addItemWithIdentifier:(ASItemIdentifier)identifier nodeBlock:(ASCellNodeBlock)nodeBlock
{
  id<ASCollectionSection> section = _currentSection;
  if (section == nil) {
    section = [self _sectionWithIdentifier:identifier appendingIfCreated:YES];
  }

  ASCollectionItemImpl *item = [self _itemWithIdentifier:identifier nodeBlock:nodeBlock];
  [section.mutableItems addObject:item];
  _usedItems[identifier] = item;
}

- (void)addSupplementaryElementOfKind:(ASSupplementaryElementKind)elementKind
                       withIdentifier:(ASItemIdentifier)identifier
                                index:(NSInteger)index
                            nodeBlock:(ASCellNodeBlock)nodeBlock
{
  ASCollectionSectionImpl *section = _currentSection;
  if (section == nil) {
    section = [self _sectionWithIdentifier:identifier appendingIfCreated:YES];
  }
  ASCollectionItemImpl *item = [self _itemWithIdentifier:identifier nodeBlock:nodeBlock];
  [_supplementaryElementKinds addObject:elementKind];
  [section setSupplementaryElement:item ofKind:elementKind atIndex:index];
  _usedItems[identifier] = item;
}

#pragma mark - Item / Section Access (Public)

- (id<ASCollectionItem>)itemWithIdentifier:(ASItemIdentifier)identifier nodeBlock:(nonnull ASCellNodeBlock)nodeBlock
{
  ASDisplayNodeAssertNil(_usedItems[identifier], @"Attempt to use the same item twice. Identifier: %@", identifier);
  ASCollectionItemImpl *item = [self _itemWithIdentifier:identifier nodeBlock:nodeBlock];
  _usedItems[identifier] = item;
  return item;
}

- (id<ASCollectionSection>)sectionWithIdentifier:(ASSectionIdentifier)identifier
{
  ASDisplayNodeAssertNil(_usedSections[identifier], @"Attempt to use the same section twice. Identifier: %@", identifier);
  return [self _sectionWithIdentifier:identifier appendingIfCreated:NO];
}

#pragma mark - Framework Accessors

- (NSMutableSet *)supplementaryElementKinds
{
  return [_supplementaryElementKinds mutableCopy];
}

- (NSArray *)sectionsInternal
{
  return _mutableSections;
}

- (ASCollectionItemImpl *)elementOfKind:(ASSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionSectionImpl *section = self.sectionsInternal[indexPath.section];
  if (kind == ASDataControllerRowNodeKind) {
    return section.itemsInternal[indexPath.item];
  } else {
    return section.supplementaryElements[kind][@(indexPath.item)];
  }
}

- (void)markCompleted
{
  _completed = YES;
}

- (std::vector<NSInteger>)itemCounts
{
  std::vector<NSInteger> result;
  for (ASCollectionSectionImpl *section in self.sectionsInternal) {
    result.push_back(section.itemsInternal.count);
  }
  return result;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray <NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *array = [NSMutableArray array];
  [array addObject:@{ @"sections" : _mutableSections }];
  return array;
}

#pragma mark - Private

- (ASCollectionItemImpl *)_itemWithIdentifier:(ASItemIdentifier)identifier nodeBlock:(nonnull ASCellNodeBlock)nodeBlock
{
  ASCollectionItemImpl *item = _itemsDict[identifier];
  if (item == nil) {
    void (^postNodeBlock)(ASCellNode *) = _postNodeBlock;
    item = [[ASCollectionItemImpl alloc] initWithIdentifier:identifier nodeBlock:^{
      ASCellNode *node = nodeBlock();
      if (postNodeBlock != nil) {
        postNodeBlock(node);
      }
      return node;
    }];
  }
  return item;
}

- (ASCollectionSectionImpl *)_sectionWithIdentifier:(ASSectionIdentifier)identifier appendingIfCreated:(BOOL)append
{
  ASCollectionSectionImpl *section = _sectionsDict[identifier];
  if (section == nil) {
    section = [[ASCollectionSectionImpl alloc] initWithIdentifier:identifier];
    if (append) {
      [self.mutableSections addObject:section];
    }
  }
  _usedSections[identifier] = section;
  return section;
}

@end
