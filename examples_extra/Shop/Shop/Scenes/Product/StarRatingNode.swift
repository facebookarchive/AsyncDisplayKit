//
//  StarRatingNode.swift
//  Shop
//
//  Created by Dimitri on 15/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class StarRatingNode: ASDisplayNode {
    
    // MARK: - Variable
    
    private lazy var starSize: CGSize = {
        return CGSize(width: 15, height: 15)
    }()
    
    private let rating: Int
    
    private var starImageNodes: [ASDisplayNode] = []
    
    // MARK: - Object life cycle
    
    init(rating: Int) {
        self.rating = rating
        super.init()
        
        self.setupStarNodes()
        self.buildNodeHierarchy()
    }
    
    // MARK: - Star nodes setup
    
    private func setupStarNodes() {
        for i in 0..<5 {
            let imageNode = ASImageNode()
            imageNode.image = i <= self.rating ? UIImage(named: "filled_star") : UIImage(named: "unfilled_star")
            imageNode.preferredFrameSize = self.starSize
            self.starImageNodes.append(imageNode)
        }
    }
    
    // MARK: - Build node hierarchy
    
    private func buildNodeHierarchy() {
        for node in self.starImageNodes {
            self.addSubnode(node)
        }
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let layoutSpec = ASStackLayoutSpec(direction: .horizontal, spacing: 5, justifyContent: .start, alignItems: .stretch, children: self.starImageNodes)
        return layoutSpec
    }
    
}
