---
title: Batch Fetching API
layout: docs
permalink: /docs/batch-fetching-api.html
prevPage: hit-test-slop.html
nextPage: implicit-hierarchy-mgmt.html
---

AsyncDisplayKit's Batch Fetching API makes it easy for developers to add fetching of new data in chunks. In case the user scrolled to a specific range of a table or collection view the automatic batch fetching mechanism of ASDK kicks in.

You as a developer can define the point when the batch fetching mechanism should start via the `leadingScreensForBatching` property on an `ASTableView` or `ASCollectionView`. The default value for this property is 2.0.

To support batch fetching you have to implement two methods in your ASTableView or ASCollectionView delegate object:
The first method you have to implement is for ASTableView delegate:

`- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView`

or for ASCollectionView delegate:

`- (BOOL)shouldBatchFetchForCollectionView:(ASCollectionView *)collectionView`

In this method you have decide if the batch fetching mechanism should kick in  if the user scrolled in batch fetching range or not. Usually this decision is based on if there is still data to fetch or not, based on e.g. previous API calls or some local dataset operations.

If you return NO from `- (BOOL)shouldBatchFetchForCollectionView:(ASCollectionView *)collectionView`, no new batch fetching process will happen, in case you return YES the batch fetching mechanism will start and the following method is called for your ASTableView delegate:

    - (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context;

or for ASCollectionView delegate:

    - (void)collectionView:(ASCollectionView *)collectionView willBeginBatchFetchWithContext:(ASBatchContext *)context;

First of all, you have to be careful within this method as it's called on a background thread. If you have to do anything on the main thread, you are responsible for dispatching it to the main thread and proceed with work you have to do in process to finish the batch fetch.

Within `- (void)collectionView:(ASCollectionView *)collectionView willBeginBatchFetchWithContext:(ASBatchContext *)context;` you should do any necessary steps to fetch the next chunk of data e.g. from a local database, an API etc.

After you finished fetching the next chunk of data, it is very important to let ASDK know that you finished the process. To do that you have to call `completeBatchFetching:` on the `context` object that was passed in with a parameter value of YES. This assures that the whole batch fetching mechanism stays in sync and a next batch fetching cycle can happen. Only by passing YES will the context know to attempt another batch update when necessary. If you pass in NO nothing will happen.

Here you can see an example how a batch fetching cycle could look like:

```objective-c
- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView 
{
  // Decide if the batch fetching mechanism should kick in
  if (_stillDataToFetch) {
    return YES;
  }
  return NO;
}

- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context 
{
  // Fetch data most of the time asynchronoulsy from an API or local database
  NSArray *data = ...;

  // Insert data into table or collection view
  [self insertNewRowsInTableView:newPhotos];

  // Decide if it's still necessary to trigger more batch fetches in the future
  _stillDataToFetch = ...;

  // Properly finish the batch fetch
  [context completeBatchFetching:YES]
}
```

Check out the following sample apps to see the batch fetching API implemented within an app:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CatDealsCollectionView">CatDealsCollectionView</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASCollectionView">ASCollectionView</a></li>
</ul>
