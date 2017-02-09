//
//  ProductCellNode.swift
//  Shop
//
//  Created by Dimitri on 15/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ProductCellNode: ASCellNode {
    
    // MARK: - Variables

    private let productNode: ProductNode
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.productNode = ProductNode(product: product)
        super.init()
        self.selectionStyle = .none
        self.addSubnode(self.productNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsets.zero, child: self.productNode)
    }
    
}
