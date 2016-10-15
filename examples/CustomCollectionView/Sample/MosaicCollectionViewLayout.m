//
//  MosaicCollectionViewLayout.m
//  Sample
//
//  Created by McCallum, Levi on 11/22/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "MosaicCollectionViewLayout.h"

@implementation MosaicCollectionViewLayout {
  NSMutableArray *_columnHeights;
  NSMutableArray *_itemAttributes;
  NSMutableDictionary *_headerAttributes;
  NSMutableArray *_allAttributes;
}

- (instancetype)init
{
  self = [super init];
  if (self != nil) {
    self.numberOfColumns = 3;
    self.columnSpacing = 10.0;
    self.sectionInset = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
    self.interItemSpacing = UIEdgeInsetsMake(10.0, 0, 10.0, 0);
  }
  return self;
}

- (void)prepareLayout
{
  _itemAttributes = [NSMutableArray array];
  _columnHeights = [NSMutableArray array];
  _allAttributes = [NSMutableArray array];
  _headerAttributes = [NSMutableDictionary dictionary];
  
  CGFloat top = 0;
  
  NSInteger numberOfSections = [self.collectionView numberOfSections];
  for (NSUInteger section = 0; section < numberOfSections; section++) {
    NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
    
    top += _sectionInset.top;
    
    if (_headerHeight > 0) {
      CGSize headerSize = [self _headerSizeForSection:section];
      UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes
                                                      layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                      withIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]];
      attributes.frame = CGRectMake(_sectionInset.left, top, headerSize.width, headerSize.height);
      _headerAttributes[@(section)] = attributes;
      [_allAttributes addObject:attributes];
      top = CGRectGetMaxY(attributes.frame);
    }
    
    [_columnHeights addObject:[NSMutableArray array]];
    for (NSUInteger idx = 0; idx < self.numberOfColumns; idx++) {
      [_columnHeights[section] addObject:@(top)];
    }
    
    CGFloat columnWidth = [self _columnWidthForSection:section];
    [_itemAttributes addObject:[NSMutableArray array]];
    for (NSUInteger idx = 0; idx < numberOfItems; idx++) {
      NSUInteger columnIndex = [self _shortestColumnIndexInSection:section];
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:section];
      
      CGSize itemSize = [self _itemSizeAtIndexPath:indexPath];
      CGFloat xOffset = _sectionInset.left + (columnWidth + _columnSpacing) * columnIndex;
      CGFloat yOffset = [_columnHeights[section][columnIndex] floatValue];
      
      UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes
                                                      layoutAttributesForCellWithIndexPath:indexPath];
      attributes.frame = CGRectMake(xOffset, yOffset, itemSize.width, itemSize.height);
      
      _columnHeights[section][columnIndex] = @(CGRectGetMaxY(attributes.frame) + _interItemSpacing.bottom);
      
      [_itemAttributes[section] addObject:attributes];
      [_allAttributes addObject:attributes];
    }
    
    NSUInteger columnIndex = [self _tallestColumnIndexInSection:section];
    top = [_columnHeights[section][columnIndex] floatValue] - _interItemSpacing.bottom + _sectionInset.bottom;
    
    for (NSUInteger idx = 0; idx < [_columnHeights[section] count]; idx++) {
      _columnHeights[section][idx] = @(top);
    }
  }
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
  NSMutableArray *includedAttributes = [NSMutableArray array];
  // Slow search for small batches
  for (UICollectionViewLayoutAttributes *attributes in _allAttributes) {
    if (CGRectIntersectsRect(attributes.frame, rect)) {
      [includedAttributes addObject:attributes];
    }
  }
  return includedAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section >= _itemAttributes.count) {
    return nil;
  } else if (indexPath.item >= [_itemAttributes[indexPath.section] count]) {
    return nil;
  }
  return _itemAttributes[indexPath.section][indexPath.item];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  if ([elementKind isEqualToString:UICollectionElementKindSectionHeader]) {
    return _headerAttributes[@(indexPath.section)];
  }
  return nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
  if (!CGSizeEqualToSize(self.collectionView.bounds.size, newBounds.size)) {
    return YES;
  }
  return NO;
}

- (CGFloat)_widthForSection:(NSUInteger)section
{
  return self.collectionView.bounds.size.width - _sectionInset.left - _sectionInset.right;
}

- (CGFloat)_columnWidthForSection:(NSUInteger)section
{
  return ([self _widthForSection:section] - ((_numberOfColumns - 1) * _columnSpacing)) / _numberOfColumns;
}

- (CGSize)_itemSizeAtIndexPath:(NSIndexPath *)indexPath
{
  CGSize size = CGSizeMake([self _columnWidthForSection:indexPath.section], 0);
  CGSize originalSize = [[self _delegate] collectionView:self.collectionView layout:self originalItemSizeAtIndexPath:indexPath];
  if (originalSize.height > 0 && originalSize.width > 0) {
    size.height = originalSize.height / originalSize.width * size.width;
  }
  return size;
}

- (CGSize)_headerSizeForSection:(NSUInteger)section
{
  return CGSizeMake([self _widthForSection:section], _headerHeight);
}

- (CGSize)collectionViewContentSize
{
  CGFloat height = [[[_columnHeights lastObject] firstObject] floatValue];
  return CGSizeMake(self.collectionView.bounds.size.width, height);
}

- (NSUInteger)_tallestColumnIndexInSection:(NSUInteger)section
{
  __block NSUInteger index = 0;
  __block CGFloat tallestHeight = 0;
  [_columnHeights[section] enumerateObjectsUsingBlock:^(NSNumber *height, NSUInteger idx, BOOL *stop) {
    if (height.floatValue > tallestHeight) {
      index = idx;
      tallestHeight = height.floatValue;
    }
  }];
  return index;
}

- (NSUInteger)_shortestColumnIndexInSection:(NSUInteger)section
{
  __block NSUInteger index = 0;
  __block CGFloat shortestHeight = CGFLOAT_MAX;
  [_columnHeights[section] enumerateObjectsUsingBlock:^(NSNumber *height, NSUInteger idx, BOOL *stop) {
    if (height.floatValue < shortestHeight) {
      index = idx;
      shortestHeight = height.floatValue;
    }
  }];
  return index;
}

- (id<MosaicCollectionViewLayoutDelegate>)_delegate
{
  return (id<MosaicCollectionViewLayoutDelegate>)self.collectionView.delegate;
}

@end

@implementation MosaicCollectionViewLayoutInspector

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  MosaicCollectionViewLayout *layout = (MosaicCollectionViewLayout *)[collectionView collectionViewLayout];
  return ASSizeRangeMake(CGSizeZero, [layout _itemSizeAtIndexPath:indexPath]);
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  MosaicCollectionViewLayout *layout = (MosaicCollectionViewLayout *)[collectionView collectionViewLayout];
  return ASSizeRangeMake(CGSizeZero, [layout _headerSizeForSection:indexPath.section]);
}

/**
 * Asks the inspector for the number of supplementary views for the given kind in the specified section.
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
    return 1;
  } else {
    return 0;
  }
}

@end
