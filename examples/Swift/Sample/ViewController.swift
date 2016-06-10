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
    var itemCount: Int
    var fetchingMore: Bool
    static let empty = State(itemCount: 20, fetchingMore: false)
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

  // MARK: ASTableView data source and delegate.

  func tableView(tableView: ASTableView, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
    // Should read the row count directly from table view but
    // https://github.com/facebook/AsyncDisplayKit/issues/1159
    let rowCount = self.tableView(tableView, numberOfRowsInSection: 0)

    if state.fetchingMore && indexPath.row == rowCount - 1 {
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
    var count = state.itemCount
    if state.fetchingMore {
      count += 1
    }
    return count
  }

  func tableView(tableView: ASTableView, willBeginBatchFetchWithContext context: ASBatchContext) {
    /// This call will come in on a background thread. Switch to main
    /// to add our spinner, then fire off our fetch.
    dispatch_async(dispatch_get_main_queue()) {
      let oldState = self.state
      self.state = ViewController.handleAction(.BeginBatchFetch, fromState: oldState)
      self.renderDiff(oldState)
    }

    ViewController.fetchDataWithCompletion { resultCount in
      let action = Action.EndBatchFetch(resultCount: resultCount)
      let oldState = self.state
      self.state = ViewController.handleAction(action, fromState: oldState)
      self.renderDiff(oldState)
      context.completeBatchFetching(true)
    }
  }

  private func renderDiff(oldState: State) {
    let tableView = tableNode.view
    tableView.beginUpdates()

    // Add or remove items
    let rowCountChange = state.itemCount - oldState.itemCount
    if rowCountChange > 0 {
      let indexPaths = (oldState.itemCount..<state.itemCount).map { index in
        NSIndexPath(forRow: index, inSection: 0)
      }
      tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
    } else if rowCountChange < 0 {
      assertionFailure("Deleting rows is not implemented. YAGNI.")
    }

    // Add or remove spinner.
    if state.fetchingMore != oldState.fetchingMore {
      if state.fetchingMore {
        // Add spinner.
        let spinnerIndexPath = NSIndexPath(forRow: state.itemCount, inSection: 0)
        tableView.insertRowsAtIndexPaths([ spinnerIndexPath ], withRowAnimation: .None)
      } else {
        // Remove spinner.
        let spinnerIndexPath = NSIndexPath(forRow: oldState.itemCount, inSection: 0)
        tableView.deleteRowsAtIndexPaths([ spinnerIndexPath ], withRowAnimation: .None)
      }
    }
    tableView.endUpdatesAnimated(false, completion: nil)
  }

  /// (Pretend) fetches some new items and calls the
  /// completion handler on the main thread.
  private static func fetchDataWithCompletion(completion: (Int) -> Void) {
    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC) * 0.5))
    dispatch_after(time, dispatch_get_main_queue()) {
      let resultCount = Int(arc4random_uniform(20))
      completion(resultCount)
    }
  }

  private static func handleAction(action: Action, var fromState state: State) -> State {
    switch action {
    case .BeginBatchFetch:
      state.fetchingMore = true
    case let .EndBatchFetch(resultCount):
      state.itemCount += resultCount
      state.fetchingMore = false
    }
    return state
  }
}
