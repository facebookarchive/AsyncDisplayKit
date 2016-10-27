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

  private func setupNodes() {
    titleNode.backgroundColor = .blue
    titleNode.attributedText = NSAttributedString.attributedString(string: "Headline!", fontSize: 14, color: .white, firstWordColor: nil)

    subtitleNode.backgroundColor = .yellow
    subtitleNode.attributedText = NSAttributedString(string: "Lorem ipsum dolor sit amet, sed ex laudem utroque meliore, at cum lucilius vituperata. Ludus mollis consulatu mei eu, esse vocent epicurei sed at. Ut cum recusabo prodesset. Ut cetero periculis sed, mundi senserit est ut. Nam ut sonet mandamus intellegebat, summo voluptaria vim ad.")
  }

  // This is used to expose this function for overriding in extensions
  override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    return ASLayoutSpec()
  }

  public func show() {
    display(inRect: .zero)
  }
}
