//
//  OverviewCellNode.swift
//  Sample
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

import AsyncDisplayKit

class OverviewCellNode: ASCellNode {

  let layoutExampleType: LayoutExampleNode.Type

  fileprivate let titleNode = ASTextNode()
  fileprivate let descriptionNode = ASTextNode()

  init(layoutExampleType le: LayoutExampleNode.Type) {
    layoutExampleType = le

    super.init()
    self.automaticallyManagesSubnodes = true

    titleNode.attributedText = NSAttributedString.attributedString(string: layoutExampleType.title(), fontSize: 16, color: .black)
    descriptionNode.attributedText = NSAttributedString.attributedString(string: layoutExampleType.descriptionTitle(), fontSize: 12, color: .lightGray)
  }

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let verticalStackSpec = ASStackLayoutSpec.vertical()
    verticalStackSpec.alignItems = .start
    verticalStackSpec.spacing = 5.0
    verticalStackSpec.children = [titleNode, descriptionNode]

    return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 10), child: verticalStackSpec)
  }

}
