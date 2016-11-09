//
//  OverviewViewController.swift
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import AsyncDisplayKit

class OverviewViewController: ASViewController<ASTableNode> {
  let tableNode = ASTableNode()
  let layoutExamples: [LayoutExampleNode.Type]

  init() {
    layoutExamples = [
      HeaderWithRightAndLeftItems.self,
      PhotoWithInsetTextOverlay.self,
      PhotoWithOutsetIconOverlay.self,
      FlexibleSeparatorSurroundingContent.self
    ]

    super.init(node: tableNode)

    self.title = "Layout Examples"
    self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    tableNode.delegate = self
    tableNode.dataSource = self
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let indexPath = tableNode.indexPathForSelectedRow {
      tableNode.deselectRow(at: indexPath, animated: true)
    }
  }

}

extension OverviewViewController: ASTableDataSource {
  func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
    return layoutExamples.count
  }

  func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
    return OverviewCellNode(layoutExampleType: layoutExamples[indexPath.row])
  }
}

extension OverviewViewController: ASTableDelegate {
  func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
    let layoutExampleType = (tableNode.nodeForRow(at: indexPath) as! OverviewCellNode).layoutExampleType
    let detail = LayoutExampleViewController(layoutExampleType: layoutExampleType)
    self.navigationController?.pushViewController(detail, animated: true)
  }
}
