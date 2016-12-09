//
//  ShopCellNode.swift
//  Shop
//
//  Created by Dimitri on 14/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ShopCellNode: ASCellNode {
    
    // MARK: - Variables
    
    private let containerNode: ContainerNode
    private let categoryNode: CategoryNode
    
    // MARK: - Object life cycle
    
    init(category: Category) {
        categoryNode = CategoryNode(category: category)
        containerNode = ContainerNode(node: categoryNode)
        super.init()
        self.selectionStyle = .none
        self.addSubnode(self.containerNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsetsMake(5, 10, 5, 10), child: self.containerNode)
    }
    
}

class ContainerNode: ASDisplayNode {
    
    // MARK: - Variables
    
    private let contentNode: ASDisplayNode
    
    // MARK: - Object life cycle
    
    init(node: ASDisplayNode) {
        contentNode = node
        super.init()
        self.backgroundColor = UIColor.containerBackgroundColor()
        self.addSubnode(self.contentNode)
    }
    
    // MARK: - Node life cycle
    
    override func didLoad() {
        super.didLoad()
        self.layer.cornerRadius = 5.0
        self.layer.borderColor = UIColor.containerBorderColor().cgColor
        self.layer.borderWidth = 1.0
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsetsMake(8, 8, 8, 8), child: self.contentNode)
    }
    
}

class CategoryNode: ASDisplayNode {
    
    // MARK: - Variables
    
    private let imageNode: ASNetworkImageNode
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    
    // MARK: - Object life cycle
    
    init(category: Category) {
        imageNode = ASNetworkImageNode()
        imageNode.url = URL(string: category.imageURL)
        
        titleNode = ASTextNode()
        let title = NSAttributedString(string: category.title, attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17)])
        titleNode.attributedText = title
        
        subtitleNode = ASTextNode()
        let subtitle = NSAttributedString(string: "\(category.numberOfProducts) products", attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 15)])
        subtitleNode.attributedText = subtitle
        
        super.init()
        
        self.imageNode.addSubnode(self.titleNode)
        self.imageNode.addSubnode(self.subtitleNode)
        self.addSubnode(self.imageNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let textNodesStack = ASStackLayoutSpec(direction: .vertical, spacing: 5, justifyContent: .end, alignItems: .stretch, children: [self.titleNode, self.subtitleNode])
        let insetStack = ASInsetLayoutSpec(insets: UIEdgeInsetsMake(CGFloat.infinity, 10, 10, 10), child: textNodesStack)
        return ASOverlayLayoutSpec(child: self.imageNode, overlay: insetStack)
    }
    
}
