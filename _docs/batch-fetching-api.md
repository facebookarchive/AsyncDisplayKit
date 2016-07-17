---
title: Batch Fetching API
layout: docs
permalink: /docs/batch-fetching-api.html
prevPage: hit-test-slop.html
nextPage: implicit-hierarchy-mgmt.html
---

AsyncDisplayKit's Batch Fetching API makes it easy to add fetching chunks of new data.  Usually this would be done in a `-scrollViewDidScroll:` method, but ASDK provides a more structured mechanism.

By default, as a user is scrolling, when they approach the point in the table or collection where they are 2 "screens" away from the end of the current content, the table will try to fetch more data.

If you'd like to configure how far away from the end you should be, just change the `leadingScreensForBatching` property on an `ASTableView` or `ASCollectionView` to something else.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
tableNode.view.leadingScreensForBatching = 3.0;  // overriding default of 2.0
</pre>
<pre lang="swift" class = "swiftCode hidden">
tableNode.view.leadingScreensForBatching = 3.0  // overriding default of 2.0
</pre>
</div>
</div>

### Batch Fetching Delegate Methods

The first thing you have to do in order to support batch fetching, is implement a method that decides if it's an appropriate time to load new content or not.

For tables it would look something like:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView
{
  if (_weNeedMoreContent) {
    return YES;
  }

  return NO;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
func shouldBatchFetchForTableView(tableView: ASTableView) -> Bool {
  if (weNeedMoreContent) {
    return true
  }

  return false
}
</pre>
</div>
</div>

and for collections:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">

- (BOOL)shouldBatchFetchForCollectionView:(ASCollectionView *)collectionView
{
  if (_weNeedMoreContent) {
    return YES;
  }

  return NO;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
func shouldBatchFetchForCollectionView(collectionView: ASCollectionView) -> Bool {
  if (weNeedMoreContent) {
    return true
  }

  return false
}
</pre>
</div>
</div>

These methods will be called when the user has scrolled into the batch fetching range, and their answer will determine if another request actually needs to be made or not.  Usually this decision is based on if there is still data to fetch.

If you return NO, then no new batch fetching process will happen.  If you return YES, the batch fetching mechanism will start and the following method will be called next.

`-tableView:willBeginBatchFetchWithContext:`

or

`-collectionView:willBeginBatchFetchWithContext:`

This is where you should actually fetch data, be it from a web API or some local database.

<div class = "note">
<strong>Note:</strong> This method will always be called on a background thread.  This means, if you need to do any work on the main thread, you should dispatch it to the main thread and then proceed with the work needed in order to finish the batch fetch operation.
</div>

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context 
{
  // Fetch data most of the time asynchronoulsy from an API or local database
  NSArray *newPhotos = [SomeSource getNewPhotos];

  // Insert data into table or collection view
  [self insertNewRowsInTableView:newPhotos];

  // Decide if it's still necessary to trigger more batch fetches in the future
  _stillDataToFetch = ...;

  // Properly finish the batch fetch
  [context completeBatchFetching:YES]
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
func tableView(tableView: ASTableView, willBeginBatchFetchWithContext context: ASBatchContext) {
  // Fetch data most of the time asynchronoulsy from an API or local database
  let newPhotos = SomeSource.getNewPhotos()

  // Insert data into table or collection view
  insertNewRowsInTableView(newPhotos)

  // Decide if it's still necessary to trigger more batch fetches in the future
  stillDataToFetch = ...

  // Properly finish the batch fetch
  context.completeBatchFetching(true)
}
</pre>
</div>
</div>

Once you've finished fetching your data, it is very important to let ASDK know that you have finished the process. To do that, you need to call `-completeBatchFetching:` on the `context` object that was passed in with a parameter value of `YES`. This assures that the whole batch fetching mechanism stays in sync and the next batch fetching cycle can happen.  Only by passing `YES` will the context know to attempt another batch update when necessary.

Check out the following sample apps to see the batch fetching API in action:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CatDealsCollectionView">CatDealsCollectionView</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASCollectionView">ASCollectionView</a></li>
</ul>
