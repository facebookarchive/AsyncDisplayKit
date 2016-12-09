//
//  ProductNode.swift
//  Shop
//
//  Created by Dimitri on 15/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ProductNode: ASDisplayNode {
    
    // MARK: - Variables
    
    private let imageNode: ASNetworkImageNode
    private let titleNode: ASTextNode
    private let priceNode: ASTextNode
    private let starRatingNode: StarRatingNode
    private let reviewsNode: ASTextNode
    private let descriptionNode: ASTextNode
    
    private let product: Product
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.product = product
        
        imageNode = ASNetworkImageNode()
        titleNode = ASTextNode()
        starRatingNode = StarRatingNode(rating: product.starRating)
        priceNode = ASTextNode()
        reviewsNode = ASTextNode()
        descriptionNode = ASTextNode()
        
        super.init()
        self.setupNodes()
        self.buildNodeHierarchy()
    }
    
    // MARK: - Setup nodes
    
    private func setupNodes() {
        self.setupImageNode()
        self.setupTitleNode()
        self.setupDescriptionNode()
        self.setupPriceNode()
        self.setupReviewsNode()
    }
    
    private func setupImageNode() {
        self.imageNode.url = URL(string: self.product.imageURL)
        self.imageNode.preferredFrameSize = CGSize(width: UIScreen.main.bounds.width, height: 300)
    }
    
    private func setupTitleNode() {
        self.titleNode.attributedText = NSAttributedString(string: self.product.title, attributes: self.titleTextAttributes())
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    private var titleTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.black, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 16)]
    }
    
    private func setupDescriptionNode() {
        self.descriptionNode.attributedText = NSAttributedString(string: self.product.descriptionText, attributes: self.descriptionTextAttributes())
        self.descriptionNode.maximumNumberOfLines = 0
    }
    
    private var descriptionTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.darkGray, NSFontAttributeName: UIFont.systemFont(ofSize: 14)]
    }
    
    private func setupPriceNode() {
        self.priceNode.attributedText = NSAttributedString(string: self.product.currency + " \(self.product.price)", attributes: self.priceTextAttributes())
    }
    
    private var priceTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.red, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 15)]
    }
    
    private func setupReviewsNode() {
        self.reviewsNode.attributedText = NSAttributedString(string: "\(self.product.numberOfReviews) reviews", attributes: self.reviewsTextAttributes())
    }
    
    private var reviewsTextAttributes = {
        return [NSForegroundColorAttributeName: UIColor.lightGray, NSFontAttributeName: UIFont.systemFont(ofSize: 14)]
    }
    
    // MARK: - Build node hierarchy
    
    private func buildNodeHierarchy() {
        self.addSubnode(imageNode)
        self.addSubnode(titleNode)
        self.addSubnode(descriptionNode)
        self.addSubnode(starRatingNode)
        self.addSubnode(priceNode)
        self.addSubnode(reviewsNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spacer = ASLayoutSpec()
        spacer.flexGrow = true
        self.titleNode.flexShrink = true
        let titlePriceSpec = ASStackLayoutSpec(direction: .horizontal, spacing: 2.0, justifyContent: .start, alignItems: .center, children: [self.titleNode, spacer, self.priceNode])
        titlePriceSpec.alignSelf = .stretch
        let starRatingReviewsSpec = ASStackLayoutSpec(direction: .horizontal, spacing: 25.0, justifyContent: .start, alignItems: .center, children: [self.starRatingNode, self.reviewsNode])
        let contentSpec = ASStackLayoutSpec(direction: .vertical, spacing: 8.0, justifyContent: .start, alignItems: .stretch, children: [titlePriceSpec, starRatingReviewsSpec, self.descriptionNode])
        contentSpec.flexShrink = true
        let insetSpec = ASInsetLayoutSpec(insets: UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0), child: contentSpec)
        let finalSpec = ASStackLayoutSpec(direction: .vertical, spacing: 5.0, justifyContent: .start, alignItems: .center, children: [self.imageNode, insetSpec])
        return finalSpec
    }
    
}
