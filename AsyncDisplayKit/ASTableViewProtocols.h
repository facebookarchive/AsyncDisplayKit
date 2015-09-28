/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * This is a subset of UITableViewDataSource.
 *
 * @see ASTableViewDataSource
 */
@protocol ASCommonTableViewDataSource <NSObject>

@required

- (NSInteger)tableView:(UITableView * _Nonnull)tableView numberOfRowsInSection:(NSInteger)section;

@optional

- (NSInteger)numberOfSectionsInTableView:(UITableView * _Nonnull)tableView;

- (NSString * _Nullable)tableView:(UITableView * _Nonnull)tableView titleForHeaderInSection:(NSInteger)section;
- (NSString * _Nullable)tableView:(UITableView * _Nonnull)tableView titleForFooterInSection:(NSInteger)section;

- (BOOL)tableView:(UITableView * _Nonnull)tableView canEditRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (BOOL)tableView:(UITableView * _Nonnull)tableView canMoveRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (NSArray<NSString *> * _Nullable)sectionIndexTitlesForTableView:(UITableView * _Nonnull)tableView;
- (NSInteger)tableView:(UITableView * _Nonnull)tableView sectionForSectionIndexTitle:(NSString * _Nonnull)title atIndex:(NSInteger)index;

- (void)tableView:(UITableView * _Nonnull)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (void)tableView:(UITableView * _Nonnull)tableView moveRowAtIndexPath:(NSIndexPath * _Nonnull)sourceIndexPath toIndexPath:(NSIndexPath * _Nonnull)destinationIndexPath;

@end


/**
 * This is a subset of UITableViewDelegate.
 *
 * @see ASTableViewDelegate
 */
@protocol ASCommonTableViewDelegate <NSObject, UIScrollViewDelegate>

@optional



- (void)tableView:(UITableView * _Nonnull)tableView willDisplayHeaderView:(UIView * _Nonnull)view forSection:(NSInteger)section;
- (void)tableView:(UITableView * _Nonnull)tableView willDisplayFooterView:(UIView * _Nonnull)view forSection:(NSInteger)section;
- (void)tableView:(UITableView * _Nonnull)tableView didEndDisplayingHeaderView:(UIView * _Nonnull)view forSection:(NSInteger)section;
- (void)tableView:(UITableView * _Nonnull)tableView didEndDisplayingFooterView:(UIView * _Nonnull)view forSection:(NSInteger)section;

- (CGFloat)tableView:(UITableView * _Nonnull)tableView heightForHeaderInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView * _Nonnull)tableView heightForFooterInSection:(NSInteger)section;

- (UIView * _Nullable)tableView:(UITableView * _Nonnull)tableView viewForHeaderInSection:(NSInteger)section;
- (UIView * _Nullable)tableView:(UITableView * _Nonnull)tableView viewForFooterInSection:(NSInteger)section;

- (void)tableView:(UITableView * _Nonnull)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (BOOL)tableView:(UITableView * _Nonnull)tableView shouldHighlightRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (void)tableView:(UITableView * _Nonnull)tableView didHighlightRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (void)tableView:(UITableView * _Nonnull)tableView didUnhighlightRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (NSIndexPath * _Nonnull)tableView:(UITableView * _Nonnull)tableView willSelectRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (NSIndexPath * _Nonnull)tableView:(UITableView * _Nonnull)tableView willDeselectRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (void)tableView:(UITableView * _Nonnull)tableView didSelectRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (void)tableView:(UITableView * _Nonnull)tableView didDeselectRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (UITableViewCellEditingStyle)tableView:(UITableView * _Nonnull)tableView editingStyleForRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (NSString * _Nullable)tableView:(UITableView * _Nonnull)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (NSArray<UITableViewRowAction *> * _Nullable)tableView:(UITableView * _Nonnull)tableView editActionsForRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (BOOL)tableView:(UITableView * _Nonnull)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (void)tableView:(UITableView * _Nonnull)tableView willBeginEditingRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (void)tableView:(UITableView * _Nonnull)tableView didEndEditingRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (NSIndexPath * _Nonnull)tableView:(UITableView * _Nonnull)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath * _Nonnull)sourceIndexPath toProposedIndexPath:(NSIndexPath * _Nonnull)proposedDestinationIndexPath;

- (NSInteger)tableView:(UITableView * _Nonnull)tableView indentationLevelForRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;

- (BOOL)tableView:(UITableView * _Nonnull)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath;
- (BOOL)tableView:(UITableView * _Nonnull)tableView canPerformAction:(SEL _Nonnull)action forRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath withSender:(id _Nullable)sender;
- (void)tableView:(UITableView * _Nonnull)tableView performAction:(SEL _Nonnull)action forRowAtIndexPath:(NSIndexPath * _Nonnull)indexPath withSender:(id _Nullable)sender;

@end
