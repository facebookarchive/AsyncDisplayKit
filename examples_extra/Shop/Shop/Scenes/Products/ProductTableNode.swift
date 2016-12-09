//
//  ProductTableNode.swift
//  Shop
//
//  Created by Dimitri on 15/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ProductTableNode: ASCellNode {

    // MARK: - Variables
    
    private lazy var imageSize: CGSize = {
        return CGSize(width: 80, height: 80)
    }()
    
    private let product: Product
    
    private let imageNode: ASNetworkImageNode
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    private let starRatingNode: StarRatingNode
    private let priceNode: ASTextNode
    private let separatorNode: ASDisplayNode
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.product = product
        
        imageNode = ASNetworkImageNode()
        titleNode = ASTextNode()
        subtitleNode = ASTextNode()
        starRatingNode = StarRatingNode(rating: product.starRating)
        priceNode = ASTextNode()
        separatorNode = ASDisplayNode()
        
        super.init()
        self.setupNodes()
        self.buildNodeHierarchy()
    }
    
    // MARK: - Setup nodes
    
    private func setupNodes() {
        self.setupImageNode()
        self.setupTitleNode()
        self.setupSubtitleNode()
        self.setupPriceNode()
        self.setupSeparatorNode()
    }
    
    private func setupImageNode() {
        self.imageNode.url = URL(string: self.product.imageURL)
        self.imageNode.preferredFrameSize = self.imageSize
    }
    
    private func setupTitleNode() {
        self.titleNode.attributedText = NSAttributedString(string: self.product.title, attributes: self.titleTextAttributes())
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    private var titleTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.black, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 16)]
    }
    
    private func setupSubtitleNode() {
        self.subtitleNode.attributedText = NSAttributedString(string: self.product.descriptionText, attributes: self.subtitleTextAttributes())
        self.subtitleNode.maximumNumberOfLines = 2
        self.subtitleNode.truncationMode = .byTruncatingTail
    }
    
    private var subtitleTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.darkGray, NSFontAttributeName: UIFont.systemFont(ofSize: 14)]
    }
    
    private func setupPriceNode() {
        self.priceNode.attributedText = NSAttributedString(string: self.product.currency + " \(self.product.price)", attributes: self.priceTextAttributes())
    }
    
    private var priceTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.red, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 15)]
    }
    
    private func setupSeparatorNode() {
        self.separatorNode.backgroundColor = UIColor.lightGray
    }
    
    // MARK: - Build node hierarchy
    
    private func buildNodeHierarchy() {
        self.addSubnode(imageNode)
        self.addSubnode(titleNode)
        self.addSubnode(subtitleNode)
        self.addSubnode(starRatingNode)
        self.addSubnode(priceNode)
        self.addSubnode(separatorNode)
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        let separatorHeight = 1 / UIScreen.main.scale
        self.separatorNode.frame = CGRect(x: 0.0, y: 0.0, width: self.calculatedSize.width, height: separatorHeight)
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spacer = ASLayoutSpec()
        spacer.flexGrow = true
        self.titleNode.flexShrink = true
        let titlePriceSpec = ASStackLayoutSpec(direction: .horizontal, spacing: 2.0, justifyContent: .start, alignItems: .center, children: [self.titleNode, spacer, self.priceNode])
        titlePriceSpec.alignSelf = .stretch
        let contentSpec = ASStackLayoutSpec(direction: .vertical, spacing: 4.0, justifyContent: .start, alignItems: .stretch, children: [titlePriceSpec, self.subtitleNode, self.starRatingNode])
        contentSpec.flexShrink = true
        let finalSpec = ASStackLayoutSpec(direction: .horizontal, spacing: 10.0, justifyContent: .start, alignItems: .start, children: [self.imageNode, contentSpec])
        return ASInsetLayoutSpec(insets: UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0), child: finalSpec)
    }
    
}
