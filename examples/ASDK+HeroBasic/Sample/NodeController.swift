//
//  ViewController.swift
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

final class ImageCenteredDisplayNode: ASDisplayNode {
  let imageNode: ASNetworkImageNode
  var onImageTap: (()->())?
  static let imageHeroId = "sample_id_0"
  
  override init() {
    imageNode = ASNetworkImageNode()
    imageNode.defaultImage = #imageLiteral(resourceName: "vancouver")
    imageNode.style.preferredSize = CGSize(width: 200, height: 356)
    imageNode.view.heroID = ImageCenteredDisplayNode.imageHeroId
    
    super.init()
    
    automaticallyManagesSubnodes = true
    backgroundColor = .white
  }
  
  override func didLoad() {
    super.didLoad()
    imageNode.addTarget(self, action: #selector(tap), forControlEvents: .touchUpInside)
  }
  
  @objc fileprivate func tap() {
    onImageTap?()
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let centerSpec = ASCenterLayoutSpec()
    centerSpec.sizingOptions = [.minimumXY]
    centerSpec.centeringOptions = .XY
    centerSpec.child = imageNode
    return centerSpec
  }
}

class NodeController: ASViewController<ImageCenteredDisplayNode> {
  init() {
    let node = ImageCenteredDisplayNode()
    super.init(node: node)
    
    node.onImageTap = { [weak self] in
      guard let `self` = self else { return }
      
      let vc = CityGuideNodeController()
      vc.isHeroEnabled = true
      vc.forceLayout()
      vc.toImageNode?.imageNode.view.heroID = ImageCenteredDisplayNode.imageHeroId
      
      self.present(vc, animated: true, completion: nil)
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("Who needs storyboards...")
  }
}

extension ASViewController {
  func forceLayout() {
    view.layoutIfNeeded()
  }
}
