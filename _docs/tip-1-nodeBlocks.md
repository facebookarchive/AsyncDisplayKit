## #1  Make sure you access your data source outside of the nodeBlock

AsyncDisplayKit’s `ASCollectionNode` replaces `UICollectionView`’s required method
```
collectionView:cellForItemAtIndexPath:
```
with your choice of **one** of the two following methods 
```
// called on main thread, ASCellNode initialized on main and then returned 
collectionView:nodeForItemAtIndexPath:           
```
```
// called on main thread, ASCellNodeBlock returned, then
// ASCellNode initialized in background when block is called by system
collectionView:nodeBlockForItemAtIndexPath:  
```

`ASTableNode` has the same options: `tableView:nodeForRow:` and `tableView:nodeBlockforRow:`. 

`ASPagerNode` does as well: `pagerNode:nodeAtIndex:` and `pagerNode:nodeBlockAtIndex:`.

**Please use the nodeBlock version**. Using the nodeBlock method allows table and collections to request blocks for each cell node, and execute them **concurrently** across multiple threads, which allows us to **parallelize the allocation costs** (in addition to layout measurement). 

This leaves our main thread more free to handle touch events and other time sensitive work, keeping our user's taps happy and responsive. 

### nodeBlock Thread Safety

Because nodeBlocks are executed on a background thread, it is very important they be thread-safe. 

The most important aspect to consider is accessing properties on self that may change, such as an array of data models. This can be handled safely by ensuring that any immutable state is collected above the node block.

**Using the indexPath parameter to access a mutable collection inside the node block is not safe.** This is because by the time the block runs, the dataSource may have changed. 

Here's an example of a simple nodeBlock:
```
- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // data model is accessed outside of the node block
    PIBoard *board = [self.boards objectAtIndex:indexPath.item];
    return ^{
        PIBoardScrubberCellNode *node = [[PIBoardScrubberCellNode alloc] initWithBoard:board];
        return node;
    };
}
```
Note that it is okay to use the indexPath if it is used strictly for its integer values and not to index a value from a mutable data source. For example, PIWrapperNode takes the indexPath.row as an argument, but only uses the value for logging purposes. This is safe.

## don't return nil from a nodeBlock

Just as when UIKit requests a cell, returning `nil` will crash the app, so it is important to ensure a valid ASCellNode is returned for either the node or nodeBlock method. Your code should ensure that at least a blank ASCellNode is returned, but ideally the number of items reported to the collection would prevent the method from being called when there is no data to display. 

## Help make our main thread lonely!

Please use nodeBlocks when developing new code. Feel free to reach out to **@rmalik** or **@htroisi** if you have any questions regarding thread safety of a node block. 

Check out https://phabricator.pinadmin.com/D103601 for examples and discussion of converting to nodeBlocks. 
