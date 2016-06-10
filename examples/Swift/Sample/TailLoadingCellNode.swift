//
//  TailLoadingCellNode.swift
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/1/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

import AsyncDisplayKit
import UIKit

final class TailLoadingCellNode: ASCellNode {
  let spinner = SpinnerNode()
  let text = ASTextNode()

  override init() {
    super.init()
    addSubnode(text)
    text.attributedString = NSAttributedString(
      string: "Loading…",
      attributes: [
        NSFontAttributeName: UIFont.systemFontOfSize(12),
        NSForegroundColorAttributeName: UIColor.lightGrayColor(),
        NSKernAttributeName: -0.3
      ])
    addSubnode(spinner)
  }

  override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {
    return ASStackLayoutSpec(
      direction: .Horizontal,
      spacing: 16,
      justifyContent: .Center,
      alignItems: .Center,
      children: [ text, spinner ])
  }
}

final class SpinnerNode: ASDisplayNode {
  var activityIndicatorView: UIActivityIndicatorView {
    return view as! UIActivityIndicatorView
  }

  override init() {
    super.init(viewBlock: { UIActivityIndicatorView(activityIndicatorStyle: .Gray) }, didLoadBlock: nil)
    preferredFrameSize.height = 32
  }

  override func didLoad() {
    super.didLoad()
    activityIndicatorView.startAnimating()
  }
}
