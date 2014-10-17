/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASTableViewProtocols.h>

@class ASCellNode;
@protocol ASTableViewDataSource;
@protocol ASTableViewDelegate;


/**
 * Node-based table view.
 *
 * ASTableView is a version of UITableView that uses nodes -- specifically, ASCellNode subclasses -- with asynchronous
 * pre-rendering instead of synchronously loading UITableViewCells.
 */
@interface ASTableView : UITableView

@property (nonatomic, weak) id<ASTableViewDataSource> asyncDataSource;
@property (nonatomic, weak) id<ASTableViewDelegate> asyncDelegate;

/**
 * Tuning parameters for the working range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
@property (nonatomic, assign) ASRangeTuningParameters rangeTuningParameters;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadData;

/**
 * WARNING:  ASTableView's update/editing support is not yet implemented.  Use of these methods will fire an assertion.
 *
 * This initial version of ASTableView only supports appending nodes (see below).  If you'd like to see full-fledged
 * support for data source updates and interactive editing, please file a GitHub issue -- AsyncDisplayKit can do it,
 * we just haven't built it out yet.  :]
 */
//- (void)beginUpdates;
//- (void)endUpdates;
//
//- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;
//
//- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
//- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;
//
//- (void)setEditing:(BOOL)editing;
//- (void)setEditing:(BOOL)editing animated:(BOOL)animated;

/**
 * Append nodes.
 *
 * As with UITableView, the asyncDataSource must be updated to reflect the new nodes before this method is called.
 *
 * @param indexPaths Ordered array of index paths corresponding to the nodes to be added.
 */
- (void)appendNodesWithIndexPaths:(NSArray *)indexPaths;

@end


/**
 * This is a node-based UITableViewDataSource.
 */
@protocol ASTableViewDataSource <ASCommonTableViewDataSource, NSObject>

/**
 * Similar to -tableView:cellForRowAtIndexPath:.
 *
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath.  Must be thread-safe (can be called on the main thread or a background
 * queue) and should not implement reuse (it will be called once per row).  Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath;

@end


/**
 * This is a node-based UITableViewDelegate.
 *
 * Note that -tableView:heightForRowAtIndexPath: has been removed; instead, your custom ASCellNode subclasses are
 * responsible for deciding their preferred onscreen height in -calculateSizeThatFits:.
 */
@protocol ASTableViewDelegate <ASCommonTableViewDelegate, NSObject>

@optional

- (void)tableView:(UITableView *)tableView willDisplayNodeForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didEndDisplayingNodeForRowAtIndexPath:(NSIndexPath*)indexPath;

@end
