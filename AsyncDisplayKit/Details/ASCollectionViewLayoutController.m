//  Copyright 2004-present Facebook. All Rights Reserved.

#import "ASCollectionViewLayoutController.h"

#import "ASAssert.h"
#import "ASCollectionView.h"


struct DirectionalBufferScreenfuls {
  NSInteger positiveDirection; // Positive relative to iOS Core Animation geometry.
  NSInteger negativeDirection;
};
typedef struct DirectionalBufferScreenfuls DirectionalBufferScreenfuls;

struct TwoDimensionalBufferScreenfuls {
  DirectionalBufferScreenfuls vertical;
  DirectionalBufferScreenfuls horizontal;
};
typedef struct TwoDimensionalBufferScreenfuls TwoDimensionalBufferScreenfuls;


@interface ASCollectionViewLayoutController () {
  ASFlowLayoutDirection _layoutDirection;
  
  NSInteger _currentPage;
  NSInteger _workingRangeStartPage;
  NSInteger _workingRangeEndPage;
  
  NSInteger _verticalCurrentPage;
  NSInteger _verticalWorkingRangeStartPage;
  NSInteger _verticalWorkingRangeEndPage;
}
@property(nonatomic, strong) UICollectionViewLayout *layout;
@end

// TODO: Follow ASDK conventions with @properties
// TODO: Determine object (ARC) ownership for layout, should it be strong?
@implementation ASCollectionViewLayoutController


- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection layout:(UICollectionViewLayout *)layout {
  if (!(self = [super initWithScrollOption:layoutDirection])) {
    return nil;
  }
  _layout = layout;
  return self;
}

/**
 * IndexPath array for the element in the working range.
 */
- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection
                     viewportSize:(CGSize)viewportSize
                        rangeType:(ASLayoutRangeType)rangeType;{

  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];
  
  NSArray *layoutAttributes = [self.layout layoutAttributesForElementsInRect:[self renderRangeRectWithScrollDirection:scrollDirection viewportSize:viewportSize]];
  for (UICollectionViewLayoutAttributes *la in layoutAttributes) {
    [indexPathSet addObject:la.indexPath];
  }
  
  return indexPathSet;
}

- (CGRect)renderRangeRectWithScrollDirection:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize {
  
  // Prep.
  TwoDimensionalBufferScreenfuls buffer = { {0, 0}, {0, 0} };
  ASRangeTuningParameters renderRangeTuningParameters = [self tuningParametersForRangeType:ASLayoutRangeTypeRender];
  ASCollectionView *asyncCollectionView = (ASCollectionView *)self.layout.collectionView;
  
  // Calculate buffer.
  BOOL canScrollVertically = ([asyncCollectionView scrollableDirections] & ASScrollDirectionUp) != 0;
  if (canScrollVertically) {
    // Calculate vertical buffer.
    BOOL movingUp = (scrollDirection & ASScrollDirectionUp) != 0;
    buffer.vertical.positiveDirection = movingUp ? renderRangeTuningParameters.trailingBufferScreenfuls :
                                                   renderRangeTuningParameters.leadingBufferScreenfuls;
    buffer.vertical.negativeDirection = movingUp ? renderRangeTuningParameters.leadingBufferScreenfuls :
                                                   renderRangeTuningParameters.trailingBufferScreenfuls;
  }
  BOOL canScrollHorizontally = ([asyncCollectionView scrollableDirections] & ASScrollDirectionLeft) != 0;
  if (canScrollHorizontally) {
    // Calculate horizontal buffer.
    BOOL movingLeft = (scrollDirection & ASScrollDirectionLeft) != 0;
    buffer.horizontal.positiveDirection = movingLeft ? renderRangeTuningParameters.trailingBufferScreenfuls :
                                                       renderRangeTuningParameters.leadingBufferScreenfuls;
    buffer.horizontal.negativeDirection = movingLeft ? renderRangeTuningParameters.leadingBufferScreenfuls :
                                                       renderRangeTuningParameters.trailingBufferScreenfuls;
  }
  
  // Calculate working rect.
  CGRect rangeRect = self.layout.collectionView.bounds;
  // Vertical expansion.
  rangeRect = CGRectOffset(rangeRect, 0, -(buffer.vertical.negativeDirection * viewportSize.height));
  rangeRect = CGRectMake(rangeRect.origin.x, MAX(rangeRect.origin.y, 0), rangeRect.size.width, ((buffer.vertical.negativeDirection + buffer.vertical.positiveDirection + 1) * viewportSize.height));
  // Horizontal expansion
  rangeRect = CGRectOffset(rangeRect, -(buffer.horizontal.negativeDirection * viewportSize.width), 0);
  rangeRect = CGRectMake(MAX(rangeRect.origin.x, 0), rangeRect.origin.y, ((buffer.horizontal.negativeDirection + buffer.horizontal.positiveDirection + 1) * viewportSize.width), rangeRect.size.height);
  NSLog(@"Range Rect: %@", NSStringFromCGRect(rangeRect));
  
  return rangeRect;
}

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths
                            viewportSize:(CGSize)viewportSize
                               rangeType:(ASLayoutRangeType)rangeType; {
  BOOL shouldUpdate = NO;
  
  if (!indexPaths.count) {
    return NO;
  }
  
  if (rangeType != ASLayoutRangeTypeRender) {
    return NO;
  }
  
  ASRangeTuningParameters renderRangeTuningParameters = [self tuningParametersForRangeType:rangeType];
  ASCollectionView *asyncCollectionView = (ASCollectionView *)self.layout.collectionView;
  
  CGRect bounds = self.layout.collectionView.bounds;
  if (CGRectIsEmpty(bounds)) {
    bounds = CGRectMake(0, 0, viewportSize.width, viewportSize.height);
  }
  
  BOOL canScrollVertically = ([asyncCollectionView scrollableDirections] & ASScrollDirectionUp) != 0;
  if (canScrollVertically) {
    CGFloat maxY = CGRectGetMaxY(bounds);
    _currentPage = floorf(maxY / bounds.size.width); // Does this care which direction moving? if moving up is it minY?
    
    BOOL movingUp = ([asyncCollectionView scrollDirection] & ASScrollDirectionDown) != 0;
    NSInteger wouldBeEnd = _currentPage + renderRangeTuningParameters.leadingBufferScreenfuls;
    NSInteger wouldBeStart = _currentPage - renderRangeTuningParameters.trailingBufferScreenfuls;
    if (movingUp) {
      wouldBeEnd = _currentPage + renderRangeTuningParameters.trailingBufferScreenfuls;
      wouldBeStart = _currentPage - renderRangeTuningParameters.leadingBufferScreenfuls;
    }
    
    if (_verticalWorkingRangeEndPage == 0 && _verticalWorkingRangeStartPage == 0) {
      _verticalWorkingRangeEndPage = wouldBeStart;
      _verticalWorkingRangeStartPage = wouldBeEnd;
      shouldUpdate = YES;
    }
    
    if ((wouldBeEnd != _verticalWorkingRangeEndPage) || (wouldBeStart != _verticalWorkingRangeStartPage)) {
      _verticalWorkingRangeStartPage = wouldBeStart;
      _verticalWorkingRangeEndPage = wouldBeEnd;
      shouldUpdate = YES;
    }
  }
  
  BOOL canScrollHorizontally = ([asyncCollectionView scrollableDirections] & ASScrollDirectionLeft) != 0;
  if (canScrollHorizontally) {
    CGFloat maxX = CGRectGetMaxX(bounds);
    _currentPage = floorf(maxX / bounds.size.width);
    
    BOOL movingLeft = ([asyncCollectionView scrollDirection] & ASScrollDirectionRight) != 0;
    NSInteger wouldBeEnd = _currentPage + renderRangeTuningParameters.leadingBufferScreenfuls;
    NSInteger wouldBeStart = _currentPage - renderRangeTuningParameters.trailingBufferScreenfuls;
    if (movingLeft) {
      wouldBeEnd = _currentPage + renderRangeTuningParameters.trailingBufferScreenfuls;
      wouldBeStart = _currentPage - renderRangeTuningParameters.leadingBufferScreenfuls;
    }
    
    if (_workingRangeEndPage == 0 && _workingRangeStartPage == 0) {
      _workingRangeStartPage = wouldBeStart;
      _workingRangeEndPage = wouldBeEnd;
      shouldUpdate = YES;
    }
    
    if ((wouldBeEnd != _workingRangeEndPage) || (wouldBeStart != _workingRangeStartPage)) {
      _workingRangeStartPage = wouldBeStart;
      _workingRangeEndPage = wouldBeEnd;
      shouldUpdate = YES;
    }
  }
  
  return shouldUpdate;
}

@end
