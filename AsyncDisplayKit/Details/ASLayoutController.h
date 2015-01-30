//  Copyright 2004-present Facebook. All Rights Reserved.

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

typedef struct {
  CGFloat leadingBufferScreenfuls;
  CGFloat trailingBufferScreenfuls;
} ASRangeTuningParameters;

typedef NS_ENUM(NSInteger, ASScrollDirection) {
  ASScrollDirectionNone,
  ASScrollDirectionRight,
  ASScrollDirectionLeft,
  ASScrollDirectionUp,
  ASScrollDirectionDown,
};

typedef NS_ENUM(NSInteger, ASLayoutRange) {
  ASLayoutRangeRender,
  ASLayoutRangePreload
};

@protocol ASLayoutController <NSObject>

/**
 * Tuning parameters for the range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
- (ASRangeTuningParameters)tuningParametersForRange:(ASLayoutRange)range;

- (void)insertNodesAtIndexPaths:(NSArray *)indexPaths withSizes:(NSArray *)nodeSizes;

- (void)deleteNodesAtIndexPaths:(NSArray *)indexPaths;

- (void)insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet;

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths;

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize range:(ASLayoutRange)range;

- (NSSet *)indexPathsForScrolling:(enum ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize range:(ASLayoutRange)range;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

- (BOOL)shouldUpdateForVisibleIndexPath:(NSArray *)indexPath viewportSize:(CGSize)viewportSize ASDISPLAYNODE_DEPRECATED;

- (NSSet *)indexPathsForScrolling:(enum ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize ASDISPLAYNODE_DEPRECATED;

@end
