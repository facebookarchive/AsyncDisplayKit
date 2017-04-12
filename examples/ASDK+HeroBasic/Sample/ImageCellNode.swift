//
//  ImageCellNode.swift
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

class ImageCellNode: ASCellNode {
  let imageNode: ASImageNode
  let titleNode: ASTextNode
  let subtitleNode: ASTextNode
  
  init(title: String, subtitle: String, image: UIImage) {
    titleNode = ASTextNode()
    titleNode.attributedText = NSAttributedString(string: title, font: UIFont.systemFont(ofSize: 20.0), fontColor: .white)
    titleNode.maximumNumberOfLines = 1
    
    subtitleNode = ASTextNode()
    subtitleNode.attributedText = NSAttributedString(string: subtitle, font: UIFont.systemFont(ofSize: 12), fontColor: .white)
    subtitleNode.maximumNumberOfLines = 1
    
    imageNode = ASImageNode()
    imageNode.contentMode = .scaleAspectFit
    imageNode.image = image
    
    super.init()
    
    cornerRadius = 7.0
    clipsToBounds = true
    
    automaticallyManagesSubnodes = true
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    imageNode.style.preferredSize = constrainedSize.max
    
    let verticalStack = ASStackLayoutSpec()
    verticalStack.direction = .vertical
    verticalStack.spacing = 12
    verticalStack.children = [titleNode, subtitleNode]
    
    let insets = UIEdgeInsets(top: CGFloat.infinity, left: 20, bottom: 25, right: 20)
    return ASOverlayLayoutSpec(child: imageNode, overlay: ASInsetLayoutSpec(insets: insets, child: verticalStack))
  }
}
