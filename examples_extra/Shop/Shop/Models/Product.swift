//
//  Product.swift
//  Shop
//
//  Created by Dimitri on 10/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import Foundation

struct Product {
    
    var id: String = UUID().uuidString
    var title: String
    var imageURL: String
    var descriptionText: String
    var price: Int
    var currency: String = "$"
    var numberOfReviews: Int
    var starRating: Int
    
    init(title: String, descriptionText: String, price: Int, imageURL: String, numberOfReviews: Int, starRating: Int) {
        self.title = title
        self.descriptionText = descriptionText
        self.price = price
        self.imageURL = imageURL
        self.numberOfReviews = numberOfReviews
        self.starRating = starRating
    }
    
}
