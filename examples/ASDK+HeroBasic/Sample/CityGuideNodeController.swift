//
//  CityGuideNodeController.swift
//  Sample
//
//  Created by Alexander Hüllmandel on 04/12/17
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
import Hero

class CityGuideNodeController: ASViewController<ASDisplayNode> {
  
  let closeButton: ASButtonNode
  let titleTextNode: ASTextNode
  let sectionTextNode: ASTextNode
  let collectionNode: ASCollectionNode
  
  let titles = ["Vancouver", "Toronto", "Montreal"]
  let subtitles = ["City in British Columbia", "City in Ontario", "City in Québec"]
  let images = [#imageLiteral(resourceName: "vancouver"), #imageLiteral(resourceName: "toronto"), #imageLiteral(resourceName: "montreal")]
  
  init() {
    closeButton = ASButtonNode()
    closeButton.setImage(#imageLiteral(resourceName: "ic_keyboard_arrow_down"), for: [])
    closeButton.style.alignSelf = .start
    closeButton.style.preferredSize = CGSize(width: 44, height: 44)
    
    titleTextNode = ASTextNode()
    titleTextNode.attributedText = NSAttributedString(string: "Adventure awaits in CANADA", font:  UIFont(name: "AvenirNext-Regular", size: 32.0)!, fontColor: .darkGray)
    
    titleTextNode.maximumNumberOfLines = 0

    sectionTextNode = ASTextNode()
    sectionTextNode.attributedText = NSAttributedString(string: "POPULAR DESTINATIONS", font:  UIFont(name: "AvenirNext-Regular", size: 16.0)!, fontColor: .darkGray)
    
    sectionTextNode.maximumNumberOfLines = 1
    
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumInteritemSpacing = 12
    collectionNode = ASCollectionNode(collectionViewLayout: layout)
    
    let node = ASDisplayNode()
    node.backgroundColor = .white
    node.automaticallyManagesSubnodes = true
    
    super.init(node: node)
    
    node.layoutSpecBlock = { [weak self] node, range in
      guard let `self` = self else { return ASLayoutSpec() }
      
      let insetCollectionNode = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 15, bottom: 20, right: 15), child: self.collectionNode)
      insetCollectionNode.style.flexGrow = 1.0
      insetCollectionNode.style.flexShrink = 1.0
      
      let verticalStack = ASStackLayoutSpec()
      verticalStack.direction = .vertical
      verticalStack.justifyContent = .start
      verticalStack.spacing = 20
      verticalStack.children = [
        ASInsetLayoutSpec(insets: UIEdgeInsets(top: 20, left: 15, bottom: 0, right: 15), child: self.closeButton),
        ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15), child: self.titleTextNode),
        ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15), child: self.sectionTextNode),
        insetCollectionNode,
      ]
      
      return verticalStack
    }
    
    collectionNode.delegate = self
    collectionNode.dataSource = self
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionNode.view.showsHorizontalScrollIndicator = false
    closeButton.addTarget(self, action: #selector(closeTapped), forControlEvents: .touchUpInside)
    
    // hero modifiers
    closeButton.view.heroModifiers = [.fade, .translate(CGPoint(x: 0, y: -150))]
    titleTextNode.view.heroModifiers = [.fade, .translate(CGPoint(x: -150, y: 0))]
    sectionTextNode.view.heroModifiers = [.fade, .translate(CGPoint(x: -150, y: 0))]
  }
  
  @objc fileprivate func closeTapped() {
    dismiss(animated: true, completion: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("Who needs storyboards...")
  }
}

extension CityGuideNodeController: ASCollectionDelegate, ASCollectionDataSource {
  func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
    return 1
  }
  
  func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
    let title = titles[indexPath.row]
    let subtitle = subtitles[indexPath.row]
    let image = images[indexPath.row]
    
    return {
      return ImageCellNode(title: title, subtitle: subtitle, image: image)
    }
  }
  
  func collectionNode(_ collectionNode: ASCollectionNode, constrainedSizeForItemAt indexPath: IndexPath) -> ASSizeRange {
    let height = collectionNode.calculatedSize.height
    return ASSizeRange(min: .zero, max: CGSize(width: 9.0/16.0*height, height: height))
  }
  
  func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
    return titles.count
  }
}

extension CityGuideNodeController {
  var toImageNode: ImageCellNode? {
    guard let imageCellNode = collectionNode.nodeForItem(at: IndexPath(item: 0, section: 0)) as? ImageCellNode else { return nil }
    return imageCellNode
  }
  
  override func forceLayout() {
    view.layoutIfNeeded()
    collectionNode.waitUntilAllUpdatesAreCommitted()
    collectionNode.view.layoutIfNeeded()
  }
}

extension NSAttributedString {
  public convenience init(string: String, font: UIFont, fontColor: UIColor? = nil, lineBreakMode: NSLineBreakMode = .byWordWrapping, textAlignment: NSTextAlignment = NSTextAlignment.natural) {
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = lineBreakMode
    paragraphStyle.alignment = textAlignment
    
    let  attributes = [NSFontAttributeName:font,
                       NSParagraphStyleAttributeName:paragraphStyle.copy(),
                       NSForegroundColorAttributeName: fontColor ?? .black]
    
    self.init(string: string, attributes: attributes)
  }
}

extension UIFont {
  /// Returns a new font with a scale applied to the font size.
  public func scaled(by: CGFloat) -> UIFont {
    return self.withSize(self.pointSize * by)
  }
  
  public func italicFont() -> UIFont {
    return self.adding(traits: [.traitItalic])
  }
  
  public func boldFont() -> UIFont {
    return self.adding(traits: [.traitBold])
  }
  
  /// Returns a new font by adding symbolic traits to the current traits.
  public func adding(traits: UIFontDescriptorSymbolicTraits) -> UIFont {
    return self.with(traits: self.fontDescriptor.symbolicTraits.union(traits))
  }
  
  /// Returns a new font with the provided symbolic traits. Old traits are not copied.
  public func with(traits: UIFontDescriptorSymbolicTraits) -> UIFont {
    
    let newFontDescriptor = fontDescriptor.withSymbolicTraits(traits)
    return UIFont(descriptor: newFontDescriptor!, size: pointSize)
  }
}
