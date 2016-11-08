//
//  LayoutExampleNode+Layouts.swift
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

extension HeaderWithRightAndLeftItems {

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let nameLocationStack = ASStackLayoutSpec.vertical()
    nameLocationStack.style.flexShrink = 1.0
    nameLocationStack.style.flexGrow = 1.0

    if postLocationNode.attributedText != nil {
      nameLocationStack.children = [userNameNode, postLocationNode]
    } else {
      nameLocationStack.children = [userNameNode]
    }

    let headerStackSpec = ASStackLayoutSpec(direction: .horizontal,
                                            spacing: 40,
                                            justifyContent: .start,
                                            alignItems: .center,
                                            children: [nameLocationStack, postTimeNode])

    return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), child: headerStackSpec)
  }

}

extension PhotoWithInsetTextOverlay {

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let photoDimension: CGFloat = constrainedSize.max.width / 4.0
    photoNode.style.preferredSize = CGSize(width: photoDimension, height: photoDimension)

    // INFINITY is used to make the inset unbounded
    let insets = UIEdgeInsets(top: CGFloat.infinity, left: 12, bottom: 12, right: 12)
    let textInsetSpec = ASInsetLayoutSpec(insets: insets, child: titleNode)

    return ASOverlayLayoutSpec(child: photoNode, overlay: textInsetSpec)
  }

}

extension PhotoWithOutsetIconOverlay {

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    iconNode.style.preferredSize = CGSize(width: 40, height: 40);
    iconNode.style.layoutPosition = CGPoint(x: 150, y: 0);

    photoNode.style.preferredSize = CGSize(width: 150, height: 150);
    photoNode.style.layoutPosition = CGPoint(x: 40 / 2.0, y: 40 / 2.0);

    let absoluteSpec = ASAbsoluteLayoutSpec(children: [photoNode, iconNode])

    // ASAbsoluteLayoutSpec's .sizing property recreates the behavior of ASDK Layout API 1.0's "ASStaticLayoutSpec"
    absoluteSpec.sizing = .sizeToFit

    return absoluteSpec;
  }

}

extension FlexibleSeparatorSurroundingContent {

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    topSeparator.style.flexGrow = 1.0
    bottomSeparator.style.flexGrow = 1.0
    textNode.style.alignSelf = .center

    let verticalStackSpec = ASStackLayoutSpec.vertical()
    verticalStackSpec.spacing = 20
    verticalStackSpec.justifyContent = .center
    verticalStackSpec.children = [topSeparator, textNode, bottomSeparator]

    return ASInsetLayoutSpec(insets:UIEdgeInsets(top: 60, left: 0, bottom: 60, right: 0), child: verticalStackSpec)
  }

}
