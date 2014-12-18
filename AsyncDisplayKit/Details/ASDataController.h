//  Copyright 2004-present Facebook. All Rights Reserved.

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDealloc2MainObject.h>

@class ASCellNode;
@class ASDataController;

/**
 Data source for data controller
 It will be invoked in the same thread as the api call of ASDataController.
 */
@protocol ASDataControllerSource <NSObject>

/**
 Fetch the ASCellNode for specific index path.
 */
- (ASCellNode *)dataController:(ASDataController *)dataController nodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 The constrained size for layout.
 */
- (CGSize)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 Fetch the number of rows in specific section.
 */
- (NSUInteger)dataController:(ASDataController *)dataControllre rowsInSection:(NSUInteger)section;

/**
 Fetch the number of sections.
 */
- (NSUInteger)dataControllerNumberOfSections:(ASDataController *)dataController;

@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

@optional

/**
 Called for insertion of elements.
 */
- (void)dataController:(ASDataController *)dataController willInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths;
- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths;

/**
 Called for deletion of elements.
 */
- (void)dataController:(ASDataController *)dataController willDeleteNodesAtIndexPaths:(NSArray *)indexPaths;
- (void)dataController:(ASDataController *)dataController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths;

/**
 Called for insertion of sections.
 */
- (void)dataController:(ASDataController *)dataController willInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet;
- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet;

/**
 Called for deletion of sections.
 */
- (void)dataController:(ASDataController *)dataController willDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet;
- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

@end


/**
 * Controller to layout data in background, and managed data updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the data
 * will be updated asynchronously. The dataSource must be updated to reflect the changes before these methods has been called.
 * For each data updatin, the corresponding methods in delegate will be called.
 */
@interface ASDataController : ASDealloc2MainObject

/**
 Data source for fetching data info.
 */
@property (nonatomic, weak) id<ASDataControllerSource> dataSource;

/**
 Delegate to notify when data is updated.
 */
@property (nonatomic, weak) id<ASDataControllerDelegate> delegate;

/** @name Initial loading */

- (void)initialDataLoading;

/** @name Data Updating */

- (void)insertSections:(NSIndexSet *)sections;

- (void)deleteSections:(NSIndexSet *)sections;

- (void)reloadSections:(NSIndexSet *)sections;

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths;

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths;

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

- (void)reloadData;

/** @name Data Querying */

- (NSUInteger)numberOfSections;

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath;

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths;

@end
