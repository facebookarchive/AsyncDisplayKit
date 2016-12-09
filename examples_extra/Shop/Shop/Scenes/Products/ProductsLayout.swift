//
//  ProductsLayout.swift
//  Shop
//
//  Created by Dimitri on 16/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ProductsLayout: UICollectionViewFlowLayout {

    // MARK: - Variables
    
    let itemHeight: CGFloat = 220
    let numberOfColumns: CGFloat = 2
    
    // MARK: - Object life cycle
    
    override init() {
        super.init()
        self.setupLayout()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupLayout()
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        self.minimumInteritemSpacing = 0
        self.minimumLineSpacing = 0
        self.scrollDirection = .vertical
    }
    
    func itemWidth() -> CGFloat {
        return (collectionView!.frame.width / numberOfColumns)
    }
    
    override var itemSize: CGSize {
        set {
            self.itemSize = CGSize(width: itemWidth(), height: itemHeight)
        }
        get {
            return CGSize(width: itemWidth(), height: itemHeight)
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return self.collectionView!.contentOffset
    }
    
}
