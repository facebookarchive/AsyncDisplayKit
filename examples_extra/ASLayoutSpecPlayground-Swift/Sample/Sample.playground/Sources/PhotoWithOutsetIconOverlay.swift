import AsyncDisplayKit

fileprivate let userImageHeight = 60

public class PhotoWithOutsetIconOverlay: ASDisplayNode, ASPlayground {
  public let photoNode = ASNetworkImageNode()
  public let iconNode  = ASNetworkImageNode()

  override public init() {
    super.init()
    backgroundColor = .white

    automaticallyManagesSubnodes = true
    setupNodes()
  }

  private func setupNodes() {
    photoNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-photo.png")
    photoNode.backgroundColor = .black

    iconNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-icon.png")
    iconNode.imageModificationBlock = ASImageNodeRoundBorderModificationBlock(10, .white)
  }

  // This is used to expose this function for overriding in extensions
  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    return ASLayoutSpec()
  }

  public func show() {
    display(inRect: CGRect(x: 0, y: 0, width: 190, height: 190))
  }
}
