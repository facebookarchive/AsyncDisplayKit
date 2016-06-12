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

class ViewController: UIViewController, ASTableViewDataSource, ASTableViewDelegate {

  var tableView: ASTableView


  // MARK: UIViewController.

  override required init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    self.tableView = ASTableView()

    super.init(nibName: nil, bundle: nil)

    self.tableView.asyncDataSource = self
    self.tableView.asyncDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("storyboards are incompatible with truth and beauty")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.tableView)
  }

  override func viewWillLayoutSubviews() {
    self.tableView.frame = self.view.bounds
  }


  // MARK: ASTableView data source and delegate.

  func tableView(tableView: ASTableView!, nodeForRowAtIndexPath indexPath: NSIndexPath!) -> ASCellNode! {
    let patter = NSString(format: "[%ld.%ld] says hello!", indexPath.section, indexPath.row)
    let node = ASTextCellNode()
    node.text = patter as String

    return node
  }

  func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
    return 1
  }

  func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
    return 20
  }

}
