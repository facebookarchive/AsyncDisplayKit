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

class ViewController: UIViewController, ASCollectionViewDataSource, ASCollectionViewDelegate {

  var collectionView: ASCollectionView


  // MARK: UIViewController.

  required override init() {
    var layout = UICollectionViewFlowLayout()
    layout.scrollDirection = UICollectionViewScrollDirection.Horizontal
    self.collectionView = ASCollectionView(frame: CGRectZero, collectionViewLayout: layout)

    super.init(nibName: nil, bundle: nil)

    self.collectionView.asyncDataSource = self
    self.collectionView.asyncDelegate = self
    self.collectionView.backgroundColor = UIColor.whiteColor()
  }

  required init(coder aDecoder: NSCoder) {
      fatalError("storyboards are incompatible with truth and beauty")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.collectionView)
  }

  override func viewWillLayoutSubviews() {
    self.collectionView.frame = self.view.bounds
  }

  override func prefersStatusBarHidden() -> Bool {
    return true
  }


  // MARK: ASCollectionView data source and delegate.

  func collectionView(collectionView: ASCollectionView!, nodeForItemAtIndexPath indexPath: NSIndexPath!) -> ASCellNode! {
    
    let text = NSString(format: "[%ld.%ld] says hi", indexPath.section, indexPath.row)
    let node = ASTextCellNode()
    node.text = text
    node.backgroundColor = UIColor.lightGrayColor()

    return node
  }

  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return 300
  }
}
