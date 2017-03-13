---
title: "Upgrading to 2.0"
layout: docs
permalink: /docs/adoption-guide-2-0-beta1.html
prevPage: adoption-guide-2-0-beta1.html
---

<ol>
<li><a href="https://usecanvas.com/htroisi/20-release-notes/1W9sFA8hIzWPco5qqCQFaf">GitHub Release Notes</a></li>
<li><a href="adoption-guide-2-0-beta1.html#getting-the-2-0-release-candidate">Getting the 2.0 Release Candidate</a></li>
<li><a href="adoption-guide-2-0-beta1.html#testing-2-0">Testing your app with 2.0</a></li>
<li><a href="adoption-guide-2-0-beta1.html#migrating-to-2-0">Migrating to 2.0</a></li>
<li><a href="adoption-guide-2-0-beta1.html#layout-api-updates">Migrating to 2.0 (Layout)</a></li>
</ol>

## Release Notes

Please read the official release notes on <a href="https://usecanvas.com/htroisi/20-release-notes/1W9sFA8hIzWPco5qqCQFaf">GitHub</a>.


## Getting the Release Candidate

Add the following to your podfile

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
pod 'AsyncDisplayKit', '>= 2.0'
</pre>
</div>
</div>

then run 

<div class = "highlight-group">
<div class = "code">
<pre lang="objc" class="objcCode">
pod repo update
pod update AsyncDisplayKit
</pre>
</div>
</div>

in the terminal.

## Testing 2.0  

Once you have updated to 2.0, you will see many deprecation warnings. Don't worry! 

These warnings are quite safe, because we have bridged all of the old APIs for you, so that you can test out the 2.0, before migrating to the new API. 

If your app fails to build instead of just showing the warnings, you might have Warnings as Errors enabled for your project. You have a few options:

1. Disable deprecation warnings in the Xcode project settings
2. Disable warnings as errors in the project's build settings.
3. Disable deprecation warnings in ASDK. To do this,  change `line 74` in `ASBaseDefines.h` to `# define ASDISPLAYNODE_WARN_DEPRECATED 0`

Once your app builds and runs, test it to make sure everything is working normally. If you find any problems, try adopting the new API in that area and re-test. 

One key behavior change you may notice:

- ASStackLayoutSpec's `.alignItems` property default changed to `ASStackLayoutAlignItemsStretch` instead of `ASStackLayoutAlignItemsStart`. This may cause distortion in your UI. 

If you still have issues, please file a GitHub issue and we'd be happy to help you out!

## Migrating to 2.0

Once your app is working, it's time to start converting! 

A full API changelog from `1.9.92` to `2.0-beta.1` is available <a href="apidiff-1992-to-20beta1.html">here</a>.

#### ASDisplayNode Changes

- ASDisplayNode's `.usesImplicitHierarchyManagement` has been renamed to `.automaticallyManagesSubnodes`. The <a href = "http://asyncdisplaykit.org/docs/automatic-subnode-mgmt.html">Automatic Subnode Management</a> API has been moved out of Beta, but has a few documented [limitations]().

- ASDisplayNode's `-cancelLayoutTransitionsInProgress` has been renamed to `-cancelLayoutTransition`. The <a href = "layout-transition-api.html">Layout Transition API</a> has been moved out of Beta. Significant new functionality is planed for future dot releases. 


#### Updated Interface State Callback Methods

The new method names are meant to unify the range update methods to show how they relate to each other and be a bit more self-explanatory:

- `didEnterPreloadState / didExitPreloadState`
- `didEnterDisplayState / didExitDisplayState`
- `didEnterVisibleState / didExitVisibleState`

These new methods replace the following:

- `loadStateDidChange:(BOOL)inLoadState`
- `displayStateDidChange:(BOOL)inDisplayState`
- `visibleStateDidChange:(BOOL)isVisible`

#### Collection / Table API Updates

AsyncDisplayKit's collection and table APIs have been moved from the view space (`collectionView`, `tableView`) to the node space (`collectionNode`, `tableNode`). 

- Search your project for `tableView` and `collectionView`. Most, if not all, of the data source / delegate methods have new node versions. 

It is important that developers using AsyncDisplayKit understand that an ASCollectionNode is backed by an ASCollectionView (a subclass of UICollectionView). ASCollectionNode runs asynchronously, so calling number -numberOfRowsInSection on the collectionNode is different than calling it on the collectionView. 

For example, let's say you have an empty table. You insert `100` rows and then immediately call -tableView:numberOfRowsInSection. This will return `0` rows. If you call -waitUntilAllUpdatesAreCommitted after insertion (waits until the collectionNode synchronizes with the collectionView), you will get 100, _but_ you might block the main thread. A good developer should rarely (or never) need to use -waitUntilAllUpdatesAreCommitted. If you update the collectionNode and then need to read back immediately, you should use the collectionNode API. You shouldn't need to talk to the collectionView.  

As a rule of thumb, use the collection / table node API for everything, unless the API is not available on the collectionNode. 

To summarize, any `indexPath` that is passed to the `collectionView` space references data that has been synced with `ASCollectionNode`'s underlying `UICollectionView`. Conversly, any `indexPath` that is passed to the `collectionNode` space references asynchronous data that *might not yet* have been synced with ASCollectionNode's underlying `UICollectionView`. The same concepts apply to `ASTableNode`.

An exception to this is `ASTableNode`'s `-didSelectRowAtIndexPath:`, which is called in UIKit space to make sure that `indexPath` indicies reference the data in the onscreen (data that has been synced to the underlying `UICollectionView` `dataSource`).

While previous versions of the framework required the developer to be aware of the asynchronous interplay between `ASCollectionNode` and its underlying `UICollectionView`, this new API should provide better safegaurds against developer-introduced data source inconsistencies. 

Other updates include:

- Deprecate `ASTableView`'s -init method. Please use `ASTableNode` instead of `ASTableView`. While this makes adopting the framework marginally more difficult to, the benefits of using ASTableNode / ASCollectionNode over their ASTableView / ASCollectionView counterparts are signficant. 

- Deprecate `-beginUpdates` and `-endUpdatesAnimated:`. Please use the `-performBatchUpdates:` methods instead.

- Deprecate `-reloadDataImmediately`. Please see the header file comments for the deprecation solution.
 
- Moved range tuning to the `tableNode` / `collectionNode` (from the `tableView` / `collectionView`)

- `constrainedSizeForNodeAtIndexPath:` moved from the `.dataSource` to the `.delegate` to be consistent with UIKit definitions of the roles. **Note:** Make sure that you provide a delegate for any `ASTableNode`, `ASCollectionNode` or `ASPagerNodes` that use this method. Your code will silently not call your delegate method, if you do not have a delegate assigned. 

- Renamed `pagerNode:constrainedSizeForNodeAtIndexPath:` to `pagerNode:constrainedSizeForNodeAtIndex:`

- collection view update validation assertions are now enabled. If you see something like `"Invalid number of items in section 2. The number of items after the update (7) must be equal to the number of items before the update (4) plus or minus the number of items inserted or removed from the section (4 inserted, 0 removed)”`, please check the data source logic. If you have any questions, reach out to us on GitHub. 

Best Practices:

- Use <a href="tip-1-nodeBlocks.html">node blocks</a> if possible. These are run in parallel on a background thread, resulting in 10x performance gains.
- Use nodes to store things about your rows.
- Make sure to batch updates that need to be batched.

Resources:

- [Video](https://youtu.be/yuDqvE5n_1g) of the ASCollectionNode Behind-the-Scenes talk at Pinterest. The <a href="/static/talks/10_3_2016_ASCollectionNode_Sequence_Diagrams.pdf">diagrams</a> seen in the talk.

- PR [#2390](https://github.com/facebook/AsyncDisplayKit/pull/2390) and PR [#2381](https://github.com/facebook/AsyncDisplayKit/pull/2381) show how we converted AsyncDisplayKit's [example projects](https://github.com/facebook/AsyncDisplayKit/tree/master/examples) to conform to this new API. 


#### Layout API Updates

Please read the separate <a href="layout2-conversion-guide.html">Layout 2.0 Conversion Guide</a> for an overview of the upgrades and to see how to convert your existing layout code. 

#### Help us out

If we're missing something from this list, please let us know or edit this doc for us (GitHub edit link at the top of page)!  
