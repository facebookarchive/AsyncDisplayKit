//
//  ViewController.swift
//  BackgroundPropertySetting
//
//  Created by Adlai Holler on 2/17/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import AsyncDisplayKit

final class ViewController: ASViewController, ASTableDelegate, ASTableDataSource {

	var tableNode: ASTableNode {
		return node as! ASTableNode
	}

	init() {
		super.init(node: ASTableNode(style: .Plain))
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Update", style: .Plain, target: self, action: "didTapUpdateButton")
		tableNode.delegate = self
		tableNode.dataSource = self
		title = "Background Node Updating Demo"
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	let rowCount = 20

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return rowCount
	}

	func tableView(tableView: ASTableView, nodeBlockForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock {
		return {
			let node = ASCellNode()
			node.backgroundColor = getRandomColor()
			return node
		}
	}

	@objc private func didTapUpdateButton() {
		let currentlyVisibleNodes = tableNode.view.visibleNodes()
		let queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
		dispatch_async(queue) {
			for case let node as ASCellNode in currentlyVisibleNodes {
				node.backgroundColor = getRandomColor()
			}
		}
	}
}

func getRandomColor() -> UIColor{

	let randomRed:CGFloat = CGFloat(drand48())

	let randomGreen:CGFloat = CGFloat(drand48())

	let randomBlue:CGFloat = CGFloat(drand48())

	return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)

}
