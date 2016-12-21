//
//  ViewController.swift
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

import UIKit
import AsyncDisplayKit

class ViewController: UIViewController, ASTableDataSource, ASTableDelegate {

  var tableNode: ASTableNode


  // MARK: UIViewController.

  override required init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    self.tableNode = ASTableNode()

    super.init(nibName: nil, bundle: nil)

    self.tableNode.dataSource = self
    self.tableNode.delegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("storyboards are incompatible with truth and beauty")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.tableNode.view)
  }

  override func viewWillLayoutSubviews() {
    self.tableNode.frame = self.view.bounds
  }


  // MARK: ASTableView data source and delegate.

  func tableNode(tableNode: ASTableNode, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
    let patter = NSString(format: "[%ld.%ld] says hello!", indexPath.section, indexPath.row)
    let node = ASTextCellNode()
    node.text = patter as String

    return node
  }

  func numberOfSectionsInTableNode(tableNode: ASTableNode) -> Int {
    return 1
  }

  func tableNode(tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
    return 20
  }

}
