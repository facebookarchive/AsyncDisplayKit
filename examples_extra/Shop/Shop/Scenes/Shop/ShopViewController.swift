//
//  ShopViewController.swift
//  Shop
//
//  Created by Dimitri on 10/11/2016.
//  Copyright © 2016 Dimitri. All rights reserved.
//

import UIKit

class ShopViewController: ASViewController<ASTableNode> {

    // MARK: - Variables
    
    lazy var categories: [Category] = {
        return DummyGenerator.sharedGenerator.randomCategories()
    }()
    
    private var tableNode: ASTableNode {
        return node 
    }
    
    // MARK: - Object life cycle
    
    init() {
        super.init(node: ASTableNode())
        tableNode.delegate = self
        tableNode.dataSource = self
        tableNode.backgroundColor = UIColor.primaryBackgroundColor()
        tableNode.view.separatorStyle = .none
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTitle()
    }

}

extension ShopViewController: ASTableDataSource, ASTableDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.categories.count
    }
    
    func tableView(_ tableView: ASTableView, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
        let category = self.categories[indexPath.row]
        let node = ShopCellNode(category: category)
        return node
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let products = self.categories[indexPath.row].products
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let tableViewAction = UIAlertAction(title: "ASTableNode", style: .default, handler: { (action) in
            let viewController = ProductsTableViewController(products: products)
            self.navigationController?.pushViewController(viewController, animated: true)
        })
        let collectionViewAction = UIAlertAction(title: "ASCollectionNode", style: .default, handler: { (action) in
            let viewController = ProductsCollectionViewController(products: products)
            self.navigationController?.pushViewController(viewController, animated: true)
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(tableViewAction)
        alertController.addAction(collectionViewAction)
        alertController.addAction(cancelAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func tableView(_ tableView: ASTableView, constrainedSizeForRowAt indexPath: IndexPath) -> ASSizeRange {
        let width = UIScreen.main.bounds.width
        return ASSizeRangeMakeExactSize(CGSize(width: width, height: 175))
    }
    
}

extension ShopViewController {
    
    func setupTitle() {
        self.title = "Bear Shop"
    }
    
}
