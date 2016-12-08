//
//  DummyGenerator.swift
//  Shop
//
//  Created by Dimitri on 14/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import Foundation

class DummyGenerator {
    
    static let sharedGenerator = DummyGenerator()
    
    // MARK: - Variables
    
    private let numberOfCategories = 15
    private let imageURLs = ["https://placebear.com/200/200",
                             "https://placebear.com/200/250",
                             "https://placebear.com/250/250",
                             "https://placebear.com/300/200",
                             "https://placebear.com/300/250",
                             "https://placebear.com/300/300",
                             "https://placebear.com/350/200",
                             "https://placebear.com/350/250",
                             "https://placebear.com/350/300"]
    
    // MARK: - Private initializer
    
    private init() {
        
    }
    
    // MARK: - Generate random categories
    
    func randomCategories() -> [Category] {
        var categories: [Category] = []
        for _ in 0..<numberOfCategories {
            let products = self.randomProducts()
            let category = Category(title: DummyGenerator.title, imageURL: imageURLs.randomItem(), products: products)
            categories.append(category)
        }
        return categories
    }
    
    // MARK: - Generate random products
    
    func randomProducts() -> [Product] {
        var products: [Product] = []
        for _ in 0..<Int(arc4random_uniform(100) + 1) {
            let title = DummyGenerator.title
            let descriptionText = DummyGenerator.paragraph
            let price = Int(arc4random_uniform(1000) + 1)
            let imageURL = imageURLs.randomItem()
            let numberOfReviews = Int(arc4random_uniform(1000) + 1)
            let starRating = Int(arc4random_uniform(5))
            let product = Product(title: title, descriptionText: descriptionText, price: price, imageURL: imageURL, numberOfReviews: numberOfReviews, starRating: starRating)
            products.append(product)
        }
        return products
    }
    
    // MARK: - Helper methods
    
    public static var word: String {
        return allWords.randomElement
    }
    
    public static func words(count: Int) -> String {
        return compose(provider: { word }, count: count, middleSeparator: .Space)
    }
    
    public static var sentence: String {
        let numberOfWordsInSentence = Int.random(min: 8, max: 16)
        let capitalizeFirstLetterDecorator: (String) -> String = { $0.stringWithCapitalizedFirstLetter }
        return compose(provider: { word }, count: numberOfWordsInSentence, middleSeparator: .Space, endSeparator: .Dot, decorator: capitalizeFirstLetterDecorator)
    }
    
    public static func sentences(count: Int) -> String {
        return compose(provider: { sentence }, count: count, middleSeparator: .Space)
    }
    
    public static var paragraph: String {
        let numberOfSentencesInParagraph = Int.random(min: 4, max: 10)
        return sentences(count: numberOfSentencesInParagraph)
    }
    
    public static func paragraphs(count: Int) -> String {
        return compose(provider: { paragraph }, count: count, middleSeparator: .NewLine)
    }
    
    public static var title: String {
        let numberOfWordsInTitle = Int.random(min: 1, max: 2)
        let capitalizeStringDecorator: (String) -> String = { $0.capitalized }
        return compose(provider: { word }, count: numberOfWordsInTitle, middleSeparator: .Space, decorator: capitalizeStringDecorator)
    }
    
    private enum Separator: String {
        case None = ""
        case Space = " "
        case Dot = "."
        case NewLine = "\n"
    }
    
    private static func compose(provider: () -> String, count: Int, middleSeparator: Separator, endSeparator: Separator = .None, decorator: ((String) -> String)? = nil) -> String {
        var composedString = ""
        
        for index in 0..<count {
            composedString += provider()
            
            if (index < count - 1) {
                composedString += middleSeparator.rawValue
            } else {
                composedString += endSeparator.rawValue
            }
        }
        
        if let decorator = decorator {
            return decorator(composedString)
        } else {
            return composedString
        }
    }
    
    // MARK: - Dummy data
    
    private static let allWords = "alias consequatur aut perferendis sit voluptatem accusantium doloremque aperiam eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo aspernatur aut odit aut fugit sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt neque dolorem ipsum quia dolor sit amet consectetur adipisci velit sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem ut enim ad minima veniam quis nostrum exercitationem ullam corporis nemo enim ipsam voluptatem quia voluptas sit suscipit laboriosam nisi ut aliquid ex ea commodi consequatur quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae et iusto odio dignissimos ducimus qui blanditiis praesentium laudantium totam rem voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident sed ut perspiciatis unde omnis iste natus error similique sunt in culpa qui officia deserunt mollitia animi id est laborum et dolorum fuga et harum quidem rerum facilis est et expedita distinctio nam libero tempore cum soluta nobis est eligendi optio cumque nihil impedit quo porro quisquam est qui minus id quod maxime placeat facere possimus omnis voluptas assumenda est omnis dolor repellendus temporibus autem quibusdam et aut consequatur vel illum qui dolorem eum fugiat quo voluptas nulla pariatur at vero eos et accusamus officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae itaque earum rerum hic tenetur a sapiente delectus ut aut reiciendis voluptatibus maiores doloribus asperiores repellat".components(separatedBy: " ")
    
    
}

private extension Array {
    func randomItem() -> Element {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}

private extension Int {
    static func random(min: Int = 0, max: Int) -> Int {
        assert(min >= 0)
        assert(min < max)
        
        return Int(arc4random_uniform(UInt32((max - min) + 1))) + min
    }
}

private extension Array {
    var randomElement: Element {
        return self[Int.random(max: count - 1)]
    }
}

private extension String {
    var stringWithCapitalizedFirstLetter: String {
        let firstLetterRange = startIndex..<self.index(after: self.startIndex)
        let capitalizedFirstLetter = substring(with: firstLetterRange).capitalized
        return replacingCharacters(in: firstLetterRange, with: capitalizedFirstLetter)
    }
}
