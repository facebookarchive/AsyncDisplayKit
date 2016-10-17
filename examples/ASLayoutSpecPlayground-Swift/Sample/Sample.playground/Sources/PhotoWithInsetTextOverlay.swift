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

  func setupNodes() {
    photoNode.url = URL(string: "http://asyncdisplaykit.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png")
    photoNode.backgroundColor = .black

    let attributes = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 16),
                      NSForegroundColorAttributeName: UIColor.white]

    titleNode.backgroundColor = .blue
    titleNode.maximumNumberOfLines = 2
    titleNode.truncationAttributedText = NSAttributedString(string: "...", attributes: attributes)
    titleNode.attributedText = NSAttributedString(string: "family fall hikes", attributes: attributes)

  }

  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    // This is to expose this function for overriding in extensions
    return ASLayoutSpec()
  }

  public func show() {
    display(inRect: CGRect(x: 0, y: 0, width: 120, height: 120))
  }
}
