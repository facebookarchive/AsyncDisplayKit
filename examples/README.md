# Sample projects

## Building

Run `pod install` in each sample project directory to set up their
dependencies.

## Example Catalog

### ASCollectionView [ObjC]

![ASCollectionView Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASCollectionView.png)
 
Featuring:
- ASCollectionView with header/footer supplementary node support
- ASCollectionView batch API
- ASDelegateProxy

### ASDKgram [ObjC]

![ASDKgram Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASDKgram.png)

### ASDKLayoutTransition [ObjC]

![ASDKLayoutTransition Example App](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASDKLayoutTransition.gif)

### ASDKTube [ObjC]

![ASDKTube Example App](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASDKTube.gif)

### ASMapNode [ObjC]

![ASMapNode Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASMapNode.png)

### ASTableViewStressTest [ObjC]

![ASTableViewStressTest Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASTableViewStressTest.png)

### ASViewController [ObjC]

![ASViewController Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/ASViewController.png)
 
Featuring:
- ASViewController
- ASTableView
- ASMultiplexImageNode
- ASLayoutSpec

### AsyncDisplayKitOverview [ObjC]

![AsyncDisplayKitOverview Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/AsyncDisplayKitOverview.png)

### BackgroundPropertySetting [Swift]

![BackgroundPropertySetting Example App gif](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/BackgroundPropertySetting.gif)
 
Featuring:
- ASDK Swift compatibility
- ASViewController
- ASCollectionView
- thread affinity
- ASLayoutSpec

### CarthageBuildTest
### CatDealsCollectionView [ObjC]

![CatDealsCollectionView Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/CatDealsCollectionView.png)
 
Featuring:
- ASCollectionView
- ASRangeTuningParameters
- Placeholder Images
- ASLayoutSpec

### CollectionViewWithViewControllerCells [ObjC]

![CollectionViewWithViewControllerCells Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/CollectionViewWithViewControllerCells.png)
 
Featuring:
- custom collection view layout
- ASLayoutSpec
- ASMultiplexImageNode

### CustomCollectionView [ObjC+Swift]

![CustomCollectionView Example App gif](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/CustomCollectionView.git)
 
Featuring:
- custom collection view layout
- ASCollectionView with sections

### EditableText [ObjC]

![EditableText Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/EditableText.png)
 
Featuring:
- ASEditableTextNode

### HorizontalwithinVerticalScrolling [ObjC]

![HorizontalwithinVerticalScrolling Example App gif](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/HorizontalwithinVerticalScrolling.gif)
 
Featuring:
- UIViewController with ASTableView
- ASCollectionView
- ASCellNode

### Kittens [ObjC]

![Kittens Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/Kittens.png)
 
Featuring:
- UIViewController with ASTableView
- ASCellNodes with ASNetworkImageNode and ASTextNode

### LayoutSpecPlayground [ObjC]

![LayoutSpecPlayground Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/LayoutSpecPlayground.png)

### Multiplex [ObjC]

![Multiplex Example App](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/Multiplex.gif)
 
Featuring:
- ASMultiplexImageNode (with artificial delay inserted)
- ASLayoutSpec

### PagerNode [ObjC]

![PagerNode Example App](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/PagerNode.gif)

Featuring:
- ASPagerNode

### Placeholders [ObjC]

Featuring:
- ASDisplayNodes now have an overidable method -placeholderImage that lets you provide a custom UIImage to display while a node is displaying asyncronously. The default implementation of this method returns nil and thus does nothing. A provided example project also demonstrates using the placeholder API.

### SocialAppLayout [ObjC]

![SocialAppLayout Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/SocialAppLayout.png)

Featuring:
- ASLayoutSpec
- UIViewController with ASTableView

### Swift [Swift]

![Swift Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/Swift.png)

Featuring:
- ASViewController with ASTableNode

### SynchronousConcurrency [ObjC]

![SynchronousConcurrency Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/SynchronousConcurrency.png)

Implementation of Synchronous Concurrency features for AsyncDisplayKit 2.0

This provides internal features on _ASAsyncTransaction and ASDisplayNode to facilitate
implementing public API that allows clients to choose if they would prefer to block
on the completion of unfinished rendering, rather than allow a placeholder state to
become visible.

The internal features are:
-[_ASAsyncTransaction waitUntilComplete]
-[ASDisplayNode recursivelyEnsureDisplay]

Also provided are two such implementations:
-[ASCellNode setNeverShowPlaceholders:], which integrates with both Tables and Collections
-[ASViewController setNeverShowPlaceholders:], which should work with Nav and Tab controllers.

Lastly, on ASDisplayNode, a new property .shouldBypassEnsureDisplay allows individual node types
to exempt themselves from blocking the main thread on their display.

By implementing the feature at the ASCellNode level rather than ASTableView & ASCollectionView,
developers can retain fine-grained control on display characteristics.  For example, certain
cell types may be appropriate to display to the user with placeholders, whereas others may not.

### SynchronousKittens [ObjC]

### VerticalWithinHorizontalScrolling [ObjC]

![VerticalWithinHorizontalScrolling Example App](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/VerticalWithinHorizontalScrolling.gif)

Features:
- UIViewController containing ASPagerNode containing ASTableNodes

### Videos [ObjC]

![VideoTableView Example App gif](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/Videos.gif)

Featuring:
- ASVideoNode

### VideoTableView [ObjC]

![VideoTableView Example App Screenshot](https://github.com/AsyncDisplayKit/Documentation/raw/master/docs/static/images/example-app-screenshots/VideoTableView.png) 

Featuring:
- ASVideoNode
- ASTableView
- ASCellNode

## License

    This file provided by Facebook is for non-commercial testing and evaluation
    purposes only.  Facebook reserves all rights not expressly granted.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
    ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
