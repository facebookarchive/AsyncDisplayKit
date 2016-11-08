//
//  LayoutExampleViewController.swift
//  Sample
//
//  Created by George on 2016-11-08.
//  Copyright © 2016 Facebook. All rights reserved.
//

import AsyncDisplayKit

class LayoutExampleViewController: ASViewController<ASDisplayNode> {

  let customNode: LayoutExampleNode

  init(layoutExampleType: LayoutExampleNode.Type) {
    customNode = layoutExampleType.init()

    super.init(node: ASDisplayNode())
    self.title = "Layout Example"

    self.node.addSubnode(customNode)
    let needsOnlyYCentering = (layoutExampleType.isEqual(HeaderWithRightAndLeftItems.self) || layoutExampleType.isEqual(FlexibleSeparatorSurroundingContent.self))

    self.node.backgroundColor = needsOnlyYCentering ? .lightGray : .white

    self.node.layoutSpecBlock = { [weak self] node, constrainedSize in
      guard let customNode = self?.customNode else { return ASLayoutSpec() }
      return ASCenterLayoutSpec(centeringOptions: needsOnlyYCentering ? .Y : .XY,
                                sizingOptions: .minimumXY,
                                child: customNode)
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
