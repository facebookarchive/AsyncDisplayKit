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

  override func prefersStatusBarHidden() -> Bool {
    return true
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
