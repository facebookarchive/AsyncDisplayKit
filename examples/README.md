# Sample projects

## Building

Run `pod install` in each sample project directory to set up their
dependencies.

## Example Catalog

### ASCollectionView [ObjC]

![ASCollectionView Example App Screenshot](./Screenshots/ASCollectionView.png?raw=true)
 
Featuring:
- ASCollectionView with header/footer supplementary node support
- ASCollectionView batch API
- ASDelegateProxy

### ASTableViewStressTest [ObjC]

![ASTableViewStressTest Example App Screenshot](./Screenshots/ASTableViewStressTest.png?raw=true)

### ASViewController [ObjC]

![ASViewController Example App Screenshot](./Screenshots/ASViewController.png?raw=true)
 
Featuring:
- ASViewController
- ASTableView
- ASMultiplexImageNode
- ASLayoutSpec

### BackgroundPropertySetting [Swift]

![BackgroundPropertySetting Example App gif](./Screenshots/BackgroundPropertySetting.gif?raw=true)
 
Featuring:
- ASDK Swift compatibility
- ASViewController
- ASCollectionView
- thread affinity
- ASLayoutSpec

### CarthageBuildTest
### CatDealsCollectionView [ObjC]

![CatDealsCollectionView Example App Screenshot](./Screenshots/CatDealsCollectionView.png?raw=true)
 
Featuring:
- ASCollectionView
- ASRangeTuningParameters
- Placeholder Images
- ASLayoutSpec

### CollectionViewWithViewControllerCells [ObjC]

![CollectionViewWithViewControllerCells Example App Screenshot](./Screenshots/CollectionViewWithViewControllerCells.png?raw=true)
 
Featuring:
- custom collection view layout
- ASLayoutSpec
- ASMultiplexImageNode

### CustomCollectionView [ObjC]

![CustomCollectionView Example App gif](./Screenshots/CustomCollectionView.gif?raw=true)
 
Featuring:
- custom collection view layout
- ASCollectionView with sections

### EditableText [ObjC]

![EditableText Example App Screenshot](./Screenshots/EditableText.png?raw=true)
 
Featuring:
- ASEditableTextNode

### HorizontalwithinVerticalScrolling [ObjC]

![HorizontalwithinVerticalScrolling Example App gif](./Screenshots/HorizontalwithinVerticalScrolling.gif?raw=true)
 
Featuring:
- UIViewController with ASTableView
- ASCollectionView
- ASCellNode

### Kittens [ObjC]

![Kittens Example App Screenshot](./Screenshots/Kittens.png?raw=true)
 
Featuring:
- UIViewController with ASTableView
- ASCellNodes with ASNetworkImageNode and ASTextNode

### Multiplex [ObjC]

![Multiplex Example App gif](./Screenshots/Multiplex.gif?raw=true)
 
Featuring:
- ASMultiplexImageNode (with artificial delay inserted)
- ASLayoutSpec

### PagerNode [ObjC]

Featuring:
- ASPagerNode

### Placeholders [ObjC]

Featuring:
- ASDisplayNodes now have an overidable method -placeholderImage that lets you provide a custom UIImage to display while a node is displaying asyncronously. The default implementation of this method returns nil and thus does nothing. A provided example project also demonstrates using the placeholder API.

### SocialAppLayout [ObjC]

![SocialAppLayout Example App Screenshot](./Screenshots/SocialAppLayout.png?raw=true)

Featuring:
- ASLayoutSpec
- UIViewController with ASTableView

### Swift [Swift]

![Swift Example App Screenshot](./Screenshots/Swift.png?raw=true)

Featuring:
- ASViewController with ASTableNode

### SynchronousConcurrency [ObjC]

![SynchronousConcurrency Example App Screenshot](./Screenshots/SynchronousConcurrency.png?raw=true)

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

![VerticalWithinHorizontalScrolling Example App Screenshot](./Screenshots/VerticalWithinHorizontalScrolling.png?raw=true)

Features:
- UIViewController containing ASPagerNode containing ASTableNodes

### Videos [ObjC]

![VideoTableView Example App gif](./Screenshots/Videos.gif?raw=true)

Featuring:
- ASVideoNode

### VideoTableView [ObjC]

![VideoTableView Example App Screenshot](./Screenshots/VideoTableView.png?raw=true) 

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
