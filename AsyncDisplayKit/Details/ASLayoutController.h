//  Copyright 2004-present Facebook. All Rights Reserved.

#import <UIKit/UIKit.h>

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

@protocol ASLayoutController <NSObject>

/**
 * Tuning parameters for the working range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
@property (nonatomic, assign) ASRangeTuningParameters tuningParameters;

- (void)insertNodesAtIndexPaths:(NSArray *)indexPaths withSizes:(NSArray *)nodeSizes;

- (void)deleteNodesAtIndexPaths:(NSArray *)indexPaths;

- (void)insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet;

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths;

- (BOOL)shouldUpdateWorkingRangesForVisibleIndexPath:(NSArray *)indexPath
                                        viewportSize:(CGSize)viewportSize;

- (NSSet *)workingRangeIndexPathsForScrolling:(enum ASScrollDirection)scrollDirection
                                 viewportSize:(CGSize)viewportSize;
@end
