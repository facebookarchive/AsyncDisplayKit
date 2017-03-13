---
title: "ASNodeController <b><i>(Beta)</i></b>"
layout: docs
permalink: /docs/containers-asnodecontroller.html
prevPage: containers-asviewcontroller.html
nextPage: containers-astablenode.html
---

<div class = "note">
To use this feature, you will need to import "ASNodeController+Beta.h" 
</div>

The ASDK team has many exciting ideas for expanding `ASNodeController`. Follow along [here](https://github.com/facebook/AsyncDisplayKit/issues/2964) if you'd like to participate in shaping the future of node controllers.

For now, `ASNodeController` remains a simple, but powerful class. 

### Example

The [example project](https://github.com/facebook/AsyncDisplayKit/pull/2945) attached in the initial PR modifies the normal [ASDKgram](https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram) project to use an `ASNodeController`.
This `PhotoCellNodeController` is used to manage the fetching of the comments data for a photo in a photo feed, once the photo enters the preload range.  This node controller allows us to separate the preloading logic from where it previously existed in the `PhotoCellNode` "view" class.

To convert ASDKgram to use an `ASNodeController`, we first create a `PhotoCellNodeController` class. 

This node controller overrides `ASNodeController`'s' `-loadNode` method to create a `PhotoCellNode` once required. It is not neccessary to call super in this method. 

This node controller also observes its node's interface state in order to intelligently preload the photo's comment feed model data when the `PhotoCellNode` enters the preload state (which indicates that the photo cell is likely to scroll onscreen soon). 

All of this logic can be removed from where it previously existed in the "view" (our `PhotoCellNode` class), leading to a more concise and MVC-friendly view class. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
@implementation PhotoCellNodeController

- (void)loadNode
{
  self.node = [[PhotoCellNode alloc] initWithPhotoObject:self.photoModel];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  CommentFeedModel *commentFeedModel = _photoModel.commentFeed;
  [commentFeedModel refreshFeedWithCompletionBlock:^(NSArray *newComments) {
    // load comments for photo
    if (commentFeedModel.numberOfItemsInFeed > 0) {
      [self.node.photoCommentsNode updateWithCommentFeedModel:commentFeedModel];
      [self.node setNeedsLayout];
    }
  }];
}

@end
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  // Click the "Edit on GitHub" button at the bottom of this page to contribute the swift code for this section. Thanks!
  </pre>
</div>
</div>

Next, we add a mutable array to the `PhotoFeedNodeController` to store our node controllers and instantiate it in the init method. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
@implementation PhotoFeedNodeController
{
  PhotoFeedModel          *_photoFeed;
  ASTableNode             *_tableNode;
  <b>NSMutableArray<PhotoCellNodeController *> *_photoCellNodeControllers;</b>
}

- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] init];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    self.navigationItem.title = @"ASDK";
    [self.navigationController setNavigationBarHidden:YES];
    
    _tableNode.dataSource = self;
    _tableNode.delegate = self;
    
    <b>_photoCellNodeControllers = [NSMutableArray array];</b>
  }
  
  return self;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  // Click the "Edit on GitHub" button at the bottom of this page to contribute the swift code for this section. Thanks!
  </pre>
</div>
</div>

To use this node controller, we modify our table row insertion logic to create a `PhotoCellNodeController` rather than a `PhotoCellNode` directly and add it to our node controller array.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (void)insertNewRowsInTableNode:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSUInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSUInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
  
    <b>// create photoCellNodeControllers for the new photos
    PhotoCellNodeController *cellController = [[PhotoCellNodeController alloc] init];
    cellController.photoModel = [_photoFeed objectAtIndex:row];
    [_photoCellNodeControllers addObject:cellController];</b>
    
    // include this index path in the insert rows call for the table
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  
  [_tableNode insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  // Click the "Edit on GitHub" button at the bottom of this page to contribute the swift code for this section. Thanks!
  </pre>
</div>
</div>

Don't forget to modify the table data source method to return the node controller rather than the cell node.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  <b>PhotoCellNodeController *cellController = [_photoCellNodeControllers objectAtIndex:indexPath.row];</b>
  // this will be executed on a background thread - important to make sure it's thread safe
  ASCellNode *(^ASCellNodeBlock)() = ^ASCellNode *() {
    PhotoCellNode *cellNode = [cellController node];
    return cellNode;
  };
  
  return ASCellNodeBlock;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  // Click the "Edit on GitHub" button at the bottom of this page to contribute the swift code for this section. Thanks!
  </pre>
</div>
</div>



