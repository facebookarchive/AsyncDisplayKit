//
//  ViewController.swift
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

import UIKit
import AsyncDisplayKit

class ViewController: UIViewController, MosaicCollectionViewLayoutDelegate, ASCollectionDataSource, ASCollectionDelegate {
  
  var _sections: [[UIImage]]?
  var _collectionNode: ASCollectionNode?
  var _layoutInspector: MosaicCollectionViewLayoutInspector?
  let kNumberOfImages: UInt = 14
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    _sections = []
    _sections!.append([]);
    
    var section = 0
    for idx in 0 ..< kNumberOfImages {
      let name = String.init(format: "image_%d.jpg", idx)
      _sections?[section].append(UIImage(named: name)!)
      if ((idx + 1) % 5 == 0 && idx < kNumberOfImages - 1) {
        section += 1
        _sections!.append([])
      }
    }
    
    let layout = MosaicCollectionViewLayout.init()
    layout.numberOfColumns = 3;
    layout.headerHeight = 44;
    layout.delegate = self
    _layoutInspector = MosaicCollectionViewLayoutInspector.init()
    
    _collectionNode = ASCollectionNode.init(frame: CGRect.zero, collectionViewLayout: layout)
    _collectionNode?.view.asyncDataSource = self;
    _collectionNode?.view.asyncDelegate = self;
    _collectionNode?.view.layoutInspector = _layoutInspector
    _collectionNode?.backgroundColor = UIColor.white
    _collectionNode?.view.isScrollEnabled = true
    _collectionNode?.registerSupplementaryNode(ofKind: UICollectionElementKindSectionHeader)
  }
  
  deinit {
    _collectionNode?.view.asyncDataSource = nil;
    _collectionNode?.view.asyncDelegate = nil;
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubnode(_collectionNode!)
  }
  
  override func viewWillLayoutSubviews() {
    _collectionNode?.frame = self.view.bounds;
  }
  
  
  // MARK: ASCollectionView data source
  func collectionView(_ collectionView: ASCollectionView, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
    let image = _sections?[indexPath.section][indexPath.item]
    return {
      return ImageCellNode.init(with: image!)
    }
  }
  
  func collectionView(_ collectionView: ASCollectionView, nodeForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> ASCellNode {
    let textAttributes : NSDictionary = [
      NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline),
      NSForegroundColorAttributeName: UIColor.gray
    ]
    let textInsets = UIEdgeInsets.init(top: 11, left: 0, bottom: 11, right: 0)
    let textCellNode = ASTextCellNode.init(attributes: textAttributes as! [AnyHashable : Any], insets: textInsets)
    textCellNode.text = String.init(format: "Section %zd", indexPath.section + 1)
    return textCellNode;
  }
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return _sections!.count
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return _sections![section].count
  }
  
  internal func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize {
    return _sections![originalItemSizeAtIndexPath.section][originalItemSizeAtIndexPath.item].size
  }
}

