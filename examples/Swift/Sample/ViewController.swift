/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import UIKit
import AsyncDisplayKit

final class ViewController: ASViewController, ASTableDataSource, ASTableDelegate {

  struct State {
    var rowCount: Int
    var showingSpinner: Bool
    static let empty = State(rowCount: 20, showingSpinner: false)
  }

  enum Action {
    case BeginBatchFetch
    case EndBatchFetch(resultCount: Int)
  }

  var tableNode: ASTableNode {
    return node as! ASTableNode
  }

  private(set) var state: State = .empty

  init() {
    super.init(node: ASTableNode())
    tableNode.delegate = self
    tableNode.dataSource = self
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("storyboards are incompatible with truth and beauty")
  }

  override func prefersStatusBarHidden() -> Bool {
    return true
  }

  // MARK: ASTableView data source and delegate.

  func tableView(tableView: ASTableView, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
    NSLog("Number of rows %d", tableView.numberOfRowsInSection(0))
    if state.showingSpinner && indexPath.row == tableView.numberOfRowsInSection(0) - 1 {
      return TailLoadingCellNode()
    }

    let node = ASTextCellNode()
    node.text = String(format: "[%ld.%ld] says hello!", indexPath.section, indexPath.row)

    return node
  }

  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    var count = state.rowCount
    if state.showingSpinner {
      count += 1
    }
    return count
  }

  func tableView(tableView: ASTableView, willBeginBatchFetchWithContext context: ASBatchContext) {
    context.cancelBatchFetching()
    dispatch_async(dispatch_get_main_queue()) {
      let oldState = self.state
      self.state = ViewController.handleAction(.BeginBatchFetch, fromState: oldState)
      self.render(oldState)
    }
    return;

    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC) * 3))
    dispatch_after(time, dispatch_get_main_queue()) {
      let action = Action.EndBatchFetch(resultCount: 20)
      let oldState = self.state
      self.state = ViewController.handleAction(action, fromState: oldState)
      self.render(oldState)
    	context.completeBatchFetching(true)
    }
  }

  func render(oldState: State) {
    let tableView = tableNode.view
    tableView.beginUpdates()

    // Add or remove items
    let rowCountChange = state.rowCount - oldState.rowCount
    if rowCountChange > 0 {
      let indexPaths = (oldState.rowCount..<state.rowCount).map { index in
        NSIndexPath(forRow: index, inSection: 0)
      }
      tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
    } else if rowCountChange < 0 {
      assertionFailure("Deleting rows is not implemented. YAGNI.")
    }

    // Add or remove spinner.
    if state.showingSpinner && !oldState.showingSpinner {
      if state.showingSpinner {
        // Add spinner.
        let spinnerIndexPath = NSIndexPath(forRow: state.rowCount, inSection: 0)
        tableView.insertRowsAtIndexPaths([ spinnerIndexPath ], withRowAnimation: .None)
      } else {
        // Remove spinner.
        let spinnerIndexPath = NSIndexPath(forRow: oldState.rowCount, inSection: 0)
        tableView.deleteRowsAtIndexPaths([ spinnerIndexPath ], withRowAnimation: .None)
      }
    }
    tableView.endUpdatesAnimated(false, completion: nil)
  }

  static func handleAction(action: Action, var fromState state: State) -> State {
    switch action {
    case .BeginBatchFetch:
      state.showingSpinner = true
    case let .EndBatchFetch(resultCount):
      state.rowCount += resultCount
      state.showingSpinner = false
    }
    return state
  }
}
