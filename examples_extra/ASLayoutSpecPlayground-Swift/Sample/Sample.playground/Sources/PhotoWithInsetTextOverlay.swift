import AsyncDisplayKit

public class PhotoWithInsetTextOverlay: ASDisplayNode, ASPlayground {
  public let photoNode = ASNetworkImageNode()
  public let titleNode = ASTextNode()

  override public init() {
    super.init()
    backgroundColor = .white

    automaticallyManagesSubnodes = true
    setupNodes()
  }

  private func setupNodes() {
    photoNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png")
    photoNode.backgroundColor = .black

    titleNode.backgroundColor = .blue
    titleNode.maximumNumberOfLines = 2
    titleNode.truncationAttributedText = NSAttributedString.attributedString(string: "...", fontSize: 16, color: .white, firstWordColor: nil)
    titleNode.attributedText = NSAttributedString.attributedString(string: "family fall hikes", fontSize: 16, color: .white, firstWordColor: nil)
  }

  // This is used to expose this function for overriding in extensions
  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    return ASLayoutSpec()
  }

  public func show() {
    display(inRect: CGRect(x: 0, y: 0, width: 120, height: 120))
  }
}
