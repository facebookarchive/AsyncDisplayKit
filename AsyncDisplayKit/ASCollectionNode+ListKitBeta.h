
#if IG_LIST_KIT

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionNode (ListKitBeta)

/**
 * The list adapter to be used with this collection node.
 * 
 * @discussion
 * @warning Use of IGListReloadDataUpdater with AsyncDisplayKit
 *   is strongly discouraged because of the cost of destroying
 *   and recreating all nodes in -reloadData.
 */
@property (nonatomic, weak) IGListAdapter *listAdapter;

@end

@protocol ASIGListSectionType <IGListSectionType>

/**
 * A method to provide the node block for the item at the given index.
 * The node block you return will be run asynchronously off the main thread,
 * so it's important to retrieve any objects from your section _outside_ the block
 * because by the time the block is run, the array may have changed.
 *
 * @param index The index of the item.
 * @return A block to be run concurrently to build the node for this item.
 * @see collectionNode:nodeBlockForItemAtIndexPath:
 */
- (ASCellNodeBlock)nodeBlockForItemAtIndex:(NSInteger)index;

@optional

/**
 * Asks the section controller whether it should batch fetch because the user is
 * near the end of the current data set.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the assumed return value is @c YES.
 */
- (BOOL)shouldBatchFetch;

/**
 * Asks the section controller to begin fetching more content (tail loading) because
 * the user is near the end of the current data set.
 *
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 */
- (void)beginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * A method to provide the constrained size used for measuring the item
 * at the given index.
 *
 * @param index The index of the item.
 * @return A constrained size used for asynchronously measuring the node at this index.
 * @see collectionNode:constrainedSizeForItemAtIndexPath:
 */
- (ASSizeRange)constrainedSizeForItemAtIndex:(NSInteger)index;

@end

@protocol ASIGListSupplementaryViewSource <IGListSupplementaryViewSource>

/**
 * A method to provide the node for the item at the given index.
 *
 * @param elementKind The kind of supplementary element.
 * @param index The index of the item.
 * @return A node for the supplementary element.
 * @see collectionNode:nodeForSupplementaryElementOfKind:atIndexPath:
 */
- (ASCellNode *)nodeForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index;

@optional

/**
 * A method to provide the constrained size used for measuring the supplementary
 * element of the given kind at the given index.
 *
 * @param elementKind The kind of supplementary element.
 * @param index The index of the item.
 * @return A constrained size used for asynchronously measuring the node.
 * @see collectionNode:constrainedSizeForSupplementaryElementOfKind:atIndexPath:
 */
- (ASSizeRange)constrainedSizeForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index;

@end

/**
 * The implementation of viewForSupplementaryElementOfKind that connects
 * IGSupplementaryViewSource to AsyncDisplayKit. Add this into the .m file
 * for your `ASIGListSupplementaryViewSource` and implement the ASDK-specific
 * method `nodeForSupplementaryElementOfKind:` to provide your node.
 *
 * @param sectionController The section controller this supplementary source is 
 * working on behalf of. For example, `self` or `self.sectionController`.
 */
#define ASIGSupplementarySourceViewForSupplementaryElementImplementation(sectionController) \
- (__kindof UICollectionReusableView *)viewForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index { \
  return [self.collectionContext dequeueReusableSupplementaryViewOfKind:elementKind forSectionController:sectionController class:[UICollectionReusableView class] atIndex:index]; \
}

/**
 * The implementation of sizeForSupplementaryViewOfKind that connects
 * IGSupplementaryViewSource to AsyncDisplayKit. Add this into the .m file
 * for your `ASIGListSupplementaryViewSource` and implement the ASDK-specific
 * method `nodeForSupplementaryElementOfKind:` to provide your node which should
 * size itself. You can set `node.style.preferredSize` if you want to fix the size.
 *
 * @param sectionController The section controller this supplementary source is
 * working on behalf of. For example, `self` or `self.sectionController`.
 */
#define ASIGSupplementarySourceSizeForSupplementaryElementImplementation \
- (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index {\
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd)); \
  return CGSizeZero; \
}


#define ASIGSectionControllerCellForIndexImplementation \
- (__kindof UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index\
{\
  return [self.collectionContext dequeueReusableCellOfClass:NSClassFromString(@"_ASCollectionViewCell") forSectionController:self atIndex:index]; \
}\

#define ASIGSectionControllerSizeForItemImplementation \
- (CGSize)sizeForItemAtIndex:(NSInteger)index \
{\
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd)); \
  return CGSizeZero;\
}

NS_ASSUME_NONNULL_END

#endif
