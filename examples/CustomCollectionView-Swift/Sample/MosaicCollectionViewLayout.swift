//
//  MosaicCollectionViewLayout
//  Sample
//
//  Created by Rajeev Gupta on 11/9/16.
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

import Foundation
import UIKit
import AsyncDisplayKit

protocol MosaicCollectionViewLayoutDelegate: ASCollectionDelegate {
  func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize
}

class MosaicCollectionViewLayout: UICollectionViewFlowLayout {
  var numberOfColumns: Int
  var columnSpacing: CGFloat
  var _sectionInset: UIEdgeInsets
  var interItemSpacing: UIEdgeInsets
  var headerHeight: CGFloat
  var _columnHeights: [[CGFloat]]?
  var _itemAttributes = [[UICollectionViewLayoutAttributes]]()
  var _headerAttributes = [UICollectionViewLayoutAttributes]()
  var _allAttributes = [UICollectionViewLayoutAttributes]()
  
  required override init() {
    self.numberOfColumns = 2
    self.columnSpacing = 10.0
    self.headerHeight = 44.0 //viewcontroller
    self._sectionInset = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)
    self.interItemSpacing = UIEdgeInsetsMake(10.0, 0, 10.0, 0)
    super.init()
    self.scrollDirection = .vertical
  }
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public var delegate : MosaicCollectionViewLayoutDelegate?
  
  override func prepare() {
    super.prepare()
    guard let collectionView = self.collectionView else { return }
    
    _itemAttributes = []
    _allAttributes = []
    _headerAttributes = []
    _columnHeights = []
    
    var top: CGFloat = 0
    
    let numberOfSections: NSInteger = collectionView.numberOfSections
    
    for section in 0 ..< numberOfSections {
      let numberOfItems = collectionView.numberOfItems(inSection: section)
      
      top += _sectionInset.top
      
      if (headerHeight > 0) {
        let headerSize: CGSize = self._headerSizeForSection(section: section)
        
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, with: NSIndexPath(row: 0, section: section) as IndexPath)
        
        attributes.frame = CGRect(x: _sectionInset.left, y: top, width: headerSize.width, height: headerSize.height)
        _headerAttributes.append(attributes)
        _allAttributes.append(attributes)
        top = attributes.frame.maxY
      }
      
      _columnHeights?.append([]) //Adding new Section
      for _ in 0 ..< self.numberOfColumns {
        self._columnHeights?[section].append(top)
      }
      
      let columnWidth = self._columnWidthForSection(section: section)
      _itemAttributes.append([])
      for idx in 0 ..< numberOfItems {
        let columnIndex: Int = self._shortestColumnIndexInSection(section: section)
        let indexPath = IndexPath(item: idx, section: section)
        
        let itemSize = self._itemSizeAtIndexPath(indexPath: indexPath);
        let xOffset = _sectionInset.left + (columnWidth + columnSpacing) * CGFloat(columnIndex)
        let yOffset = _columnHeights![section][columnIndex]
        
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemSize.width, height: itemSize.height)
        
        _columnHeights?[section][columnIndex] = attributes.frame.maxY + interItemSpacing.bottom
        
        _itemAttributes[section].append(attributes)
        _allAttributes.append(attributes)
      }
      
      let columnIndex: Int = self._tallestColumnIndexInSection(section: section)
      top = (_columnHeights?[section][columnIndex])! - interItemSpacing.bottom + _sectionInset.bottom
      
      for idx in 0 ..< _columnHeights![section].count {
        _columnHeights![section][idx] = top
      }
    }
  }
  
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    var includedAttributes: [UICollectionViewLayoutAttributes] = []
    // Slow search for small batches
    for attribute in _allAttributes {
      if (attribute.frame.intersects(rect)) {
        includedAttributes.append(attribute)
      }
    }
    return includedAttributes
  }
  
  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes?
  {
    guard indexPath.section < _itemAttributes.count,
      indexPath.item < _itemAttributes[indexPath.section].count
      else {
        return nil
    }
    return _itemAttributes[indexPath.section][indexPath.item]
  }
  
  override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes?
  {
    if (elementKind == UICollectionElementKindSectionHeader) {
      return _headerAttributes[indexPath.section]
    }
    return nil
  }
  
  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    if (!(self.collectionView?.bounds.size.equalTo(newBounds.size))!) {
      return true;
    }
    return false;
  }
  
  func _widthForSection (section: Int) -> CGFloat
  {
    return self.collectionView!.bounds.size.width - _sectionInset.left - _sectionInset.right;
  }
  
  func _columnWidthForSection(section: Int) -> CGFloat
  {
    return (self._widthForSection(section: section) - ((CGFloat(numberOfColumns - 1)) * columnSpacing)) / CGFloat(numberOfColumns)
  }
  
  func _itemSizeAtIndexPath(indexPath: IndexPath) -> CGSize
  {
    var size = CGSize(width: self._columnWidthForSection(section: indexPath.section), height: 0)
    let originalSize = self.delegate!.collectionView(self.collectionView!, layout:self, originalItemSizeAtIndexPath:indexPath)
    if (originalSize.height > 0 && originalSize.width > 0) {
      size.height = originalSize.height / originalSize.width * size.width
    }
    return size
  }
  
  func _headerSizeForSection(section: Int) -> CGSize
  {
    return CGSize(width: self._widthForSection(section: section), height: headerHeight)
  }
  
  override var collectionViewContentSize: CGSize
  {
    var height: CGFloat = 0
    if ((_columnHeights?.count)! > 0) {
      if (_columnHeights?[(_columnHeights?.count)!-1].count)! > 0 {
        height = (_columnHeights?[(_columnHeights?.count)!-1][0])!
      }
    }
    return CGSize(width: self.collectionView!.bounds.size.width, height: height)
  }
  
  func _tallestColumnIndexInSection(section: Int) -> Int
  {
    var index: Int = 0;
    var tallestHeight: CGFloat = 0;
    _ = _columnHeights?[section].enumerated().map { (idx,height) in
      if (height > tallestHeight) {
        index = idx;
        tallestHeight = height
      }
    }
    return index
  }
  
  func _shortestColumnIndexInSection(section: Int) -> Int
  {
    var index: Int = 0;
    var shortestHeight: CGFloat = CGFloat.greatestFiniteMagnitude
    _ = _columnHeights?[section].enumerated().map { (idx,height) in
      if (height < shortestHeight) {
        index = idx;
        shortestHeight = height
      }
    }
    return index
  }
  
}

class MosaicCollectionViewLayoutInspector: NSObject, ASCollectionViewLayoutInspecting
{
  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForNodeAt indexPath: IndexPath) -> ASSizeRange {
    let layout = collectionView.collectionViewLayout as! MosaicCollectionViewLayout
    return ASSizeRangeMake(CGSize.zero, layout._itemSizeAtIndexPath(indexPath: indexPath))
  }
  
  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForSupplementaryNodeOfKind: String, at atIndexPath: IndexPath) -> ASSizeRange
  {
    let layout = collectionView.collectionViewLayout as! MosaicCollectionViewLayout
    return ASSizeRange.init(min: CGSize.zero, max: layout._headerSizeForSection(section: atIndexPath.section))
  }
  
  /**
   * Asks the inspector for the number of supplementary sections in the collection view for the given kind.
   */
  func collectionView(_ collectionView: ASCollectionView, numberOfSectionsForSupplementaryNodeOfKind kind: String) -> UInt {
    if (kind == UICollectionElementKindSectionHeader) {
      return UInt((collectionView.dataSource?.numberOfSections!(in: collectionView))!)
    } else {
      return 0
    }
  }
  
  /**
   * Asks the inspector for the number of supplementary views for the given kind in the specified section.
   */
  func collectionView(_ collectionView: ASCollectionView, supplementaryNodesOfKind kind: String, inSection section: UInt) -> UInt {
    if (kind == UICollectionElementKindSectionHeader) {
      return 1
    } else {
      return 0
    }
  }
  
  func scrollableDirections() -> ASScrollDirection {
    return ASScrollDirectionVerticalDirections;
  }
}
