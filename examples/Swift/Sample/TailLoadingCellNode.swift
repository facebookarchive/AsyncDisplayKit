//
//  TailLoadingCellNode.swift
//  Sample
//
//  Created by Adlai Holler on 2/1/16.
//  Copyright © 2016 Facebook. All rights reserved.
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