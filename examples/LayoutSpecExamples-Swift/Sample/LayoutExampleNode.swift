//
//  LayoutExampleNode.swift
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

class LayoutExampleNode: ASDisplayNode {
  override required init() {
    super.init()
    automaticallyManagesSubnodes = true
    backgroundColor = .white
  }

  class func title() -> String {
    assertionFailure("All layout example nodes must provide a title!")
    return ""
  }

  class func descriptionTitle() -> String? {
    return nil
  }
}

class HeaderWithRightAndLeftItems : LayoutExampleNode {
  let userNameNode     = ASTextNode()
  let postLocationNode = ASTextNode()
  let postTimeNode     = ASTextNode()

  required init() {
    super.init()

    userNameNode.attributedText = NSAttributedString.attributedString(string: "hannahmbanana", fontSize: 20, color: .darkBlueColor())
    userNameNode.maximumNumberOfLines = 1
    userNameNode.truncationMode = .byTruncatingTail

    postLocationNode.attributedText = NSAttributedString.attributedString(string: "Sunset Beach, San Fransisco, CA", fontSize: 20, color: .lightBlueColor())
    postLocationNode.maximumNumberOfLines = 1
    postLocationNode.truncationMode = .byTruncatingTail

    postTimeNode.attributedText = NSAttributedString.attributedString(string: "30m", fontSize: 20, color: .lightGray)
    postTimeNode.maximumNumberOfLines = 1
    postTimeNode.truncationMode = .byTruncatingTail
  }

  override class func title() -> String {
    return "Header with left and right justified text"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}

class PhotoWithInsetTextOverlay : LayoutExampleNode {
  let photoNode = ASNetworkImageNode()
  let titleNode = ASTextNode()

  required init() {
    super.init()

    backgroundColor = .clear

    photoNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png")
    photoNode.willDisplayNodeContentWithRenderingContext = { context in
      let bounds = context.boundingBoxOfClipPath
      UIBezierPath(roundedRect: bounds, cornerRadius: 10).addClip()
    }

    titleNode.attributedText = NSAttributedString.attributedString(string: "family fall hikes", fontSize: 16, color: .white)
    titleNode.truncationAttributedText = NSAttributedString.attributedString(string: "...", fontSize: 16, color: .white)
    titleNode.maximumNumberOfLines = 2
    titleNode.truncationMode = .byTruncatingTail
  }

  override class func title() -> String {
    return "Photo with inset text overlay"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}

class PhotoWithOutsetIconOverlay : LayoutExampleNode {
  let photoNode = ASNetworkImageNode()
  let iconNode  = ASNetworkImageNode()

  required init() {
    super.init()

    photoNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-photo.png")

    iconNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-icon.png")

    iconNode.imageModificationBlock = { image in
      let profileImageSize = CGSize(width: 60, height: 60)
      return image.makeCircularImage(size: profileImageSize, borderWidth: 10)
    }
  }

  override class func title() -> String {
    return "Photo with outset icon overlay"
  }

  override class func descriptionTitle() -> String? {
    return nil
  }
}

class FlexibleSeparatorSurroundingContent : LayoutExampleNode {
  let topSeparator    = ASImageNode()
  let bottomSeparator = ASImageNode()
  let textNode        = ASTextNode()

  required init() {
    super.init()

    topSeparator.image = UIImage.as_resizableRoundedImage(withCornerRadius: 1.0, cornerColor: .black, fill: .black)

    textNode.attributedText = NSAttributedString.attributedString(string: "this is a long text node", fontSize: 16, color: .black)

    bottomSeparator.image = UIImage.as_resizableRoundedImage(withCornerRadius: 1.0, cornerColor: .black, fill: .black)
  }

  override class func title() -> String {
    return "Top and bottom cell separator lines"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}
