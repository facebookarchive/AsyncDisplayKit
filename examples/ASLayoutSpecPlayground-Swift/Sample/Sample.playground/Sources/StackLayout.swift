import AsyncDisplayKit

public class StackLayout: ASDisplayNode, ASPlayground {
  public let titleNode    = ASTextNode()
  public let subtitleNode = ASTextNode()

  override public init() {
    super.init()
    backgroundColor = .white

    automaticallyManagesSubnodes = true
    setupNodes()
  }

  func setupNodes() {
    titleNode.backgroundColor = .blue
    titleNode.attributedText = NSAttributedString(string: "Headline!", attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 14)])

    subtitleNode.backgroundColor = .yellow
    subtitleNode.attributedText = NSAttributedString(string: "Lorem ipsum dolor sit amet, sed ex laudem utroque meliore, at cum lucilius vituperata. Ludus mollis consulatu mei eu, esse vocent epicurei sed at. Ut cum recusabo prodesset. Ut cetero periculis sed, mundi senserit est ut. Nam ut sonet mandamus intellegebat, summo voluptaria vim ad.")
  }

  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    // This is to expose this function for overriding in extensions
    return ASLayoutSpec()
  }

  public func show() {
    display(inRect: .zero)
  }
}
