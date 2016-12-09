//
//  ProductCollectionNode.swift
//  Shop
//
//  Created by Dimitri on 15/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ProductCollectionNode: ASCellNode {

    // MARK: - Variables
    
    private let containerNode: ContainerNode
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.containerNode = ContainerNode(node: ProductContentNode(product: product))
        super.init()
        self.selectionStyle = .none
        self.addSubnode(self.containerNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let insets = UIEdgeInsetsMake(2, 2, 2, 2)
        return ASInsetLayoutSpec(insets: insets, child: self.containerNode)
    }
    
}

class ProductContentNode: ASDisplayNode {
    
    // MARK: - Variables
    
    private let imageNode: ASNetworkImageNode
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        imageNode = ASNetworkImageNode()
        imageNode.url = URL(string: product.imageURL)
        
        titleNode = ASTextNode()
        let title = NSAttributedString(string: product.title, attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17)])
        titleNode.attributedText = title
        
        subtitleNode = ASTextNode()
        let subtitle = NSAttributedString(string: product.currency + " \(product.price)", attributes: [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 15)])
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
