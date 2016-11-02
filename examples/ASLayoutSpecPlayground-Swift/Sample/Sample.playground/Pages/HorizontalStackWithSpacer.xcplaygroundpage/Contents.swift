//: [Photo With Outset Icon Overlay](PhotoWithOutsetIconOverlay)

import AsyncDisplayKit

extension HorizontalStackWithSpacer {

  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    usernameNode.style.flexShrink = 1.0
    postLocationNode.style.flexShrink = 1.0

    let verticalStackSpec = ASStackLayoutSpec.vertical()
    verticalStackSpec.style.flexShrink = 1.0

    // if fetching post location data from server, check if it is available yet
    if postLocationNode.attributedText != nil {
      verticalStackSpec.children = [usernameNode, postLocationNode]
    } else {
      verticalStackSpec.children = [usernameNode]
    }

    let spacerSpec = ASLayoutSpec()
    spacerSpec.style.flexGrow = 1.0
    spacerSpec.style.flexShrink = 1.0

    // horizontal stack
    let horizontalStack = ASStackLayoutSpec.horizontal()
    horizontalStack.alignItems = .center // center items vertically in horiz stack
    horizontalStack.justifyContent = .start // justify content to left
    horizontalStack.style.flexShrink = 1.0
    horizontalStack.style.flexGrow = 1.0
    horizontalStack.children = [verticalStackSpec, spacerSpec, postTimeNode]

    // inset horizontal stack
    let insets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    let headerInsetSpec = ASInsetLayoutSpec(insets: insets, child: horizontalStack)
    headerInsetSpec.style.flexShrink = 1.0
    headerInsetSpec.style.flexGrow = 1.0

    return headerInsetSpec
  }

}

HorizontalStackWithSpacer().show()

//: [Index](Index)
