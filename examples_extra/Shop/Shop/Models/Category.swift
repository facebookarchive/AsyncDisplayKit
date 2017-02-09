//
//  Category.swift
//  Shop
//
//  Created by Dimitri on 10/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import Foundation

struct Category {
    
    var id: String = UUID().uuidString
    var imageURL: String
    var numberOfProducts: Int = 0
    var title: String
    var products: [Product]
    
    init(title: String, imageURL: String, products: [Product]) {
        self.title = title
        self.imageURL = imageURL
        self.products = products
        self.numberOfProducts = products.count
    }
    
}
