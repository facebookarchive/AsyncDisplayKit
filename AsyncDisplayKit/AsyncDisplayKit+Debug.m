//
//  AsyncDisplayKit+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AsyncDisplayKit+Debug.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASWeakSet.h>
#import <AsyncDisplayKit/CGRect+ASConvenience.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASRangeController.h>

static BOOL __shouldShowImageScalingOverlay = NO;
static BOOL __shouldShowRangeDebugOverlay = NO;

@class _ASRangeDebugBarView;

#pragma mark - ASImageNode
@implementation ASImageNode (Debugging)

+ (void)setShouldShowImageScalingOverlay:(BOOL)show
{
  __shouldShowImageScalingOverlay = show;
}

+ (BOOL)shouldShowImageScalingOverlay
{
  return __shouldShowImageScalingOverlay;
}

@end

#pragma mark - ASRangeController
@interface _ASRangeDebugOverlayView : UIView

+ (instancetype)sharedInstance;

- (void)addRangeController:(ASRangeController *)rangeController;

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
    fetchDataTuningParameters:(ASRangeTuningParameters)fetchDataTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;

@end

@interface _ASRangeDebugBarView : UIView

@property (nonatomic, weak) ASRangeController *rangeController;
@property (nonatomic, assign) BOOL destroyOnLayout;
@property (nonatomic, strong) NSString *debugString;

+ (UIImage *)resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                             scale:(CGFloat)scale
                                   backgroundColor:(UIColor *)backgroundColor
                                         fillColor:(UIColor *)fillColor
                                       borderColor:(UIColor *)borderColor;

- (instancetype)initWithRangeController:(ASRangeController *)rangeController;

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio
                  displayRatio:(CGFloat)displayRatio
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio
                fetchDataRatio:(CGFloat)fetchDataRatio
         leadingFetchDataRatio:(CGFloat)leadingFetchDataRatio
                     direction:(ASScrollDirection)direction;

@end

@implementation ASRangeController (Debugging)

+ (void)setShouldShowRangeDebugOverlay:(BOOL)show
{
  __shouldShowRangeDebugOverlay = show;
}

+ (BOOL)shouldShowRangeDebugOverlay
{
  return __shouldShowRangeDebugOverlay;
}

+ (void)layoutDebugOverlayIfNeeded
{
  [[_ASRangeDebugOverlayView sharedInstance] setNeedsLayout];
}

- (void)addRangeControllerToRangeDebugOverlay
{
  [[_ASRangeDebugOverlayView sharedInstance] addRangeController:self];
}

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
    fetchDataTuningParameters:(ASRangeTuningParameters)fetchDataTuningParameters
               interfaceState:(ASInterfaceState)interfaceState
{
  [[_ASRangeDebugOverlayView sharedInstance] updateRangeController:controller
                                          withScrollableDirections:scrollableDirections
                                                   scrollDirection:direction
                                                         rangeMode:mode
                                           displayTuningParameters:displayTuningParameters
                                         fetchDataTuningParameters:fetchDataTuningParameters
                                                    interfaceState:interfaceState];
}

@end


#pragma mark - _ASRangeDebugOverlayView

@interface _ASRangeDebugOverlayView () <UIGestureRecognizerDelegate>
@end

@implementation _ASRangeDebugOverlayView
{
  NSMutableArray *_rangeControllerViews;
  NSInteger      _newControllerCount;
  NSInteger      _removeControllerCount;
  BOOL           _animating;
}

+ (instancetype)sharedInstance
{
  static _ASRangeDebugOverlayView *__rangeDebugOverlay = nil;
  
  if (!__rangeDebugOverlay && [ASRangeController shouldShowRangeDebugOverlay]) {
    __rangeDebugOverlay = [[self alloc] initWithFrame:CGRectZero];
    [[[NSClassFromString(@"UIApplication") sharedApplication] keyWindow] addSubview:__rangeDebugOverlay];
  }
  
  return __rangeDebugOverlay;
}

#define OVERLAY_INSET 10
#define OVERLAY_SCALE 3
- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
    _rangeControllerViews = [[NSMutableArray alloc] init];
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    self.layer.zPosition = 1000;
    self.clipsToBounds = YES;
    
    CGSize windowSize = [[[NSClassFromString(@"UIApplication") sharedApplication] keyWindow] bounds].size;
    self.frame  = CGRectMake(windowSize.width - (windowSize.width / OVERLAY_SCALE) - OVERLAY_INSET, windowSize.height - OVERLAY_INSET,
                                                 windowSize.width / OVERLAY_SCALE, 0.0);
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPanned:)];
    [self addGestureRecognizer:panGR];
    
//    UIPinchGestureRecognizer *pinchGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPinched:)];
//    [self addGestureRecognizer:pinchGR];
  }
  
  return self;
}

#define BAR_THICKNESS 24

- (void)layoutSubviews
{
  [super layoutSubviews];
  [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
    [self layoutToFitAllBarsExcept:0];
  } completion:^(BOOL finished) {
    
  }];
}

- (void)layoutToFitAllBarsExcept:(NSInteger)barsToClip
{
  CGSize boundsSize = self.bounds.size;
  CGFloat totalHeight = 0.0;
  
  CGRect barRect = CGRectMake(0, boundsSize.height - BAR_THICKNESS, self.bounds.size.width, BAR_THICKNESS);
  NSMutableArray *displayedBars = [NSMutableArray array];
  
  for (_ASRangeDebugBarView *barView in [_rangeControllerViews copy]) {
    barView.frame = barRect;
    
    ASInterfaceState interfaceState = [barView.rangeController.dataSource interfaceStateForRangeController:barView.rangeController];
    
#if ASRangeControllerLoggingEnabled
    NSLog(@"barView %p, visible = %d, display = %d, fetch = %d, destroy = %d, alpha = %f, %@", barView,
          (interfaceState & ASInterfaceStateVisible) == ASInterfaceStateVisible,
          (interfaceState & ASInterfaceStateDisplay) == ASInterfaceStateDisplay,
          (interfaceState & ASInterfaceStateFetchData) == ASInterfaceStateFetchData,
          barView.destroyOnLayout, barView.alpha, barView.debugString);
#endif
    
    if (!(interfaceState & (ASInterfaceStateVisible))) {
      if (barView.destroyOnLayout && barView.alpha == 0.0) {
        [_rangeControllerViews removeObjectIdenticalTo:barView];
        [barView removeFromSuperview];
      } else {
        barView.alpha = 0.0;
      }
    } else {
      assert(!barView.destroyOnLayout); // In this case we should not have a visible interfaceState
      barView.alpha = 1.0;
      totalHeight += BAR_THICKNESS;
      barRect.origin.y -= BAR_THICKNESS;
      [displayedBars addObject:barView];
    }
  }
  
  if (totalHeight > 0) {
    totalHeight -= (BAR_THICKNESS * barsToClip);
  }
  
  if (barsToClip == 0) {
    CGRect overlayFrame = self.frame;
    CGFloat heightChange = (overlayFrame.size.height - totalHeight);
    
    overlayFrame.origin.y += heightChange;
    overlayFrame.size.height = totalHeight;
    self.frame = overlayFrame;
    
    for (_ASRangeDebugBarView *barView in displayedBars) {
      [self offsetYOrigin:-heightChange forView:barView];
    }
  }
}

- (void)setOrigin:(CGPoint)origin forView:(UIView *)view
{
  CGRect newFrame = view.frame;
  newFrame.origin = origin;
  view.frame      = newFrame;
}

- (void)offsetYOrigin:(CGFloat)offset forView:(UIView *)view
{
  CGRect newFrame = view.frame;
  newFrame.origin = CGPointMake(newFrame.origin.x, newFrame.origin.y + offset);
  view.frame      = newFrame;
}

- (void)addRangeController:(ASRangeController *)rangeController
{
  for (_ASRangeDebugBarView *rangeView in _rangeControllerViews) {
    if (rangeView.rangeController == rangeController) {
      return;
    }
  }
  _ASRangeDebugBarView *rangeView = [[_ASRangeDebugBarView alloc] initWithRangeController:rangeController];
  [_rangeControllerViews addObject:rangeView];
  [self addSubview:rangeView];
  
  if (!_animating) {
    [self layoutToFitAllBarsExcept:1];
  }
  
  [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
    _animating = YES;
    [self layoutToFitAllBarsExcept:0];
  } completion:^(BOOL finished) {
    _animating = NO;
  }];
}

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)scrollDirection
                    rangeMode:(ASLayoutRangeMode)rangeMode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
    fetchDataTuningParameters:(ASRangeTuningParameters)fetchDataTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;
{
  _ASRangeDebugBarView *viewToUpdate = [self barViewForRangeController:controller];
  
  CGRect boundsRect = self.bounds;
  CGRect visibleRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, ASRangeTuningParametersZero, scrollableDirections, scrollDirection);
  CGRect displayRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, displayTuningParameters,     scrollableDirections, scrollDirection);
  CGRect fetchDataRect = CGRectExpandToRangeWithScrollableDirections(boundsRect, fetchDataTuningParameters,   scrollableDirections, scrollDirection);
  
  
  // figure out which is biggest and assume that is full bounds
  BOOL displayRangeLargerThanFetch    = NO;
  CGFloat visibleRatio                = 0;
  CGFloat displayRatio                = 0;
  CGFloat fetchDataRatio              = 0;
  CGFloat leadingDisplayTuningRatio   = 0;
  CGFloat leadingFetchDataTuningRatio = 0;

  if (!((displayTuningParameters.leadingBufferScreenfuls + displayTuningParameters.trailingBufferScreenfuls) == 0)) {
    leadingDisplayTuningRatio = displayTuningParameters.leadingBufferScreenfuls / (displayTuningParameters.leadingBufferScreenfuls + displayTuningParameters.trailingBufferScreenfuls);
  }
  if (!((fetchDataTuningParameters.leadingBufferScreenfuls + fetchDataTuningParameters.trailingBufferScreenfuls) == 0)) {
    leadingFetchDataTuningRatio = fetchDataTuningParameters.leadingBufferScreenfuls / (fetchDataTuningParameters.leadingBufferScreenfuls + fetchDataTuningParameters.trailingBufferScreenfuls);
  }
  
  if (ASScrollDirectionContainsVerticalDirection(scrollDirection)) {
    
    if (displayRect.size.height >= fetchDataRect.size.height) {
      displayRangeLargerThanFetch = YES;
    } else {
      displayRangeLargerThanFetch = NO;
    }
    
    if (displayRangeLargerThanFetch) {
      visibleRatio    = visibleRect.size.height / displayRect.size.height;
      displayRatio    = 1.0;
      fetchDataRatio  = fetchDataRect.size.height / displayRect.size.height;
    } else {
      visibleRatio    = visibleRect.size.height / fetchDataRect.size.height;
      displayRatio    = displayRect.size.height / fetchDataRect.size.height;
      fetchDataRatio  = 1.0;
    }

  } else {
    
    if (displayRect.size.width >= fetchDataRect.size.width) {
      displayRangeLargerThanFetch = YES;
    } else {
      displayRangeLargerThanFetch = NO;
    }
    
    if (displayRangeLargerThanFetch) {
      visibleRatio    = visibleRect.size.width / displayRect.size.width;
      displayRatio    = 1.0;
      fetchDataRatio  = fetchDataRect.size.width / displayRect.size.width;
    } else {
      visibleRatio    = visibleRect.size.width / fetchDataRect.size.width;
      displayRatio    = displayRect.size.width / fetchDataRect.size.width;
      fetchDataRatio  = 1.0;
    }
  }

  [viewToUpdate updateWithVisibleRatio:visibleRatio
                          displayRatio:displayRatio
                   leadingDisplayRatio:leadingDisplayTuningRatio
                        fetchDataRatio:fetchDataRatio
                 leadingFetchDataRatio:leadingFetchDataTuningRatio
                             direction:scrollDirection];

  [self setNeedsLayout];
}

- (_ASRangeDebugBarView *)barViewForRangeController:(ASRangeController *)controller
{
  _ASRangeDebugBarView *rangeControllerBarView = nil;
  
  for (_ASRangeDebugBarView *rangeView in [[_rangeControllerViews reverseObjectEnumerator] allObjects]) {
    // remove barView if it's rangeController has been deleted
    if (!rangeView.rangeController) {
      rangeView.destroyOnLayout = YES;
      [self setNeedsLayout];
    }
    ASInterfaceState interfaceState = [rangeView.rangeController.dataSource interfaceStateForRangeController:rangeView.rangeController];
    if (!(interfaceState & (ASInterfaceStateVisible | ASInterfaceStateDisplay))) {
      [self setNeedsLayout];
    }
    
    if ([rangeView.rangeController isEqual:controller]) {
      rangeControllerBarView = rangeView;
    }
  }
  
  return rangeControllerBarView;
}

#define MIN_VISIBLE_INSET 40
- (void)rangeDebugOverlayWasPanned:(UIPanGestureRecognizer *)recognizer
{
  CGPoint translation    = [recognizer translationInView:recognizer.view];
  CGFloat newCenterX     = recognizer.view.center.x + translation.x;
  CGFloat newCenterY     = recognizer.view.center.y + translation.y;
  CGSize boundsSize      = recognizer.view.bounds.size;
  CGSize superBoundsSize = recognizer.view.superview.bounds.size;
  CGFloat minAllowableX  = -boundsSize.width / 2.0 + MIN_VISIBLE_INSET;
  CGFloat maxAllowableX  = superBoundsSize.width + boundsSize.width / 2.0 - MIN_VISIBLE_INSET;
  
  if (newCenterX > maxAllowableX) {
    newCenterX = maxAllowableX;
  } else if (newCenterX < minAllowableX) {
    newCenterX = minAllowableX;
  }
  
  CGFloat minAllowableY = -boundsSize.height / 2.0 + MIN_VISIBLE_INSET;
  CGFloat maxAllowableY = superBoundsSize.height + boundsSize.height / 2.0 - MIN_VISIBLE_INSET;
    
  if (newCenterY > maxAllowableY) {
    newCenterY = maxAllowableY;
  } else if (newCenterY < minAllowableY) {
    newCenterY = minAllowableY;
  }
  
  recognizer.view.center = CGPointMake(newCenterX, newCenterY);
  [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view];
}

//- (void)rangeDebugOverlayWasPinched:(UIPinchGestureRecognizer *)recognizer
//{
//  recognizer.view.transform = CGAffineTransformScale(recognizer.view.transform, recognizer.scale, recognizer.scale);
//  recognizer.scale = 1;
//}

@end

#pragma mark - _ASRangeDebugBarView


@implementation _ASRangeDebugBarView
{
  ASImageNode       *_visibleRect;
  ASImageNode       *_displayRect;
  ASImageNode       *_fetchDataRect;
  ASTextNode        *_debugText;
  ASTextNode        *_leftDebugText;
  ASTextNode        *_rightDebugText;
  CGFloat           _visibleRatio;
  CGFloat           _displayRatio;
  CGFloat           _fetchDataRatio;
  CGFloat           _leadingDisplayRatio;
  CGFloat           _leadingFetchDataRatio;
  ASScrollDirection _scrollDirection;
  BOOL              _firstLayoutOfRects;
}

- (instancetype)initWithRangeController:(ASRangeController *)rangeController
{
  self = [super initWithFrame:CGRectZero];
 
  if (self) {
    _firstLayoutOfRects = YES;
    _rangeController    = rangeController;
    _debugText          = [self createDebugTextNode];
    _leftDebugText      = [self createDebugTextNode];
    _rightDebugText     = [self createDebugTextNode];
  
    _fetchDataRect = [[ASImageNode alloc] init];
    _fetchDataRect.image = [_ASRangeDebugBarView resizableRoundedImageWithCornerRadius:3
                                                                                 scale:[[UIScreen mainScreen] scale]
                                                                       backgroundColor:nil
                                                                             fillColor:[[UIColor orangeColor] colorWithAlphaComponent:0.5]
                                                                           borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
    [self addSubview:_fetchDataRect.view];
    
    _visibleRect = [[ASImageNode alloc] init];
    _visibleRect.image = [_ASRangeDebugBarView resizableRoundedImageWithCornerRadius:3
                                                                               scale:[[UIScreen mainScreen] scale]
                                                                     backgroundColor:nil
                                                                           fillColor:[[UIColor greenColor] colorWithAlphaComponent:0.5]
                                                                         borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
    [self addSubview:_visibleRect.view];
    
    _displayRect = [[ASImageNode alloc] init];
    _displayRect.image = [_ASRangeDebugBarView resizableRoundedImageWithCornerRadius:3
                                                                               scale:[[UIScreen mainScreen] scale]
                                                                     backgroundColor:nil
                                                                           fillColor:[[UIColor yellowColor] colorWithAlphaComponent:0.5]
                                                                         borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
    [self addSubview:_displayRect.view];
    }
  
  return self;
}

#define HORIZONTAL_INSET 10
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  CGSize boundsSize     = self.bounds.size;
  CGFloat subCellHeight = 9.0;
  [self setBarDebugLabelsWithSize:subCellHeight];
  [self setBarSubviewOrder];

  CGRect rect       = CGRectIntegral(CGRectMake(0, 0, boundsSize.width, floorf(boundsSize.height / 2.0)));
  rect.size         = [_debugText measure:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  rect.origin.x     = (boundsSize.width - rect.size.width) / 2.0;
  _debugText.frame  = rect;
  rect.origin.y    += rect.size.height;
  
  rect.origin.x          = 0;
  rect.size              = CGSizeMake(HORIZONTAL_INSET, boundsSize.height / 2.0);
  _leftDebugText.frame   = rect;

  rect.origin.x          = boundsSize.width - HORIZONTAL_INSET;
  _rightDebugText.frame  = rect;

  CGFloat visibleDimension   = (boundsSize.width - 2 * HORIZONTAL_INSET) * _visibleRatio;
  CGFloat displayDimension   = (boundsSize.width - 2 * HORIZONTAL_INSET) * _displayRatio;
  CGFloat fetchDataDimension = (boundsSize.width - 2 * HORIZONTAL_INSET) * _fetchDataRatio;
  CGFloat visiblePoint       = 0;
  CGFloat displayPoint       = 0;
  CGFloat fetchDataPoint     = 0;
  
  BOOL displayLargerThanFetchData = (_displayRatio == 1.0) ? YES : NO;
  
  if (ASScrollDirectionContainsLeft(_scrollDirection) || ASScrollDirectionContainsUp(_scrollDirection)) {
    
    if (displayLargerThanFetchData) {
      visiblePoint        = (displayDimension - visibleDimension) * _leadingDisplayRatio;
      fetchDataPoint      = visiblePoint - (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
    } else {
      visiblePoint        = (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * _leadingDisplayRatio;
    }
  } else if (ASScrollDirectionContainsRight(_scrollDirection) || ASScrollDirectionContainsDown(_scrollDirection)) {
    
    if (displayLargerThanFetchData) {
      visiblePoint        = (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
      fetchDataPoint      = visiblePoint - (fetchDataDimension - visibleDimension) * (1 - _leadingFetchDataRatio);
    } else {
      visiblePoint        = (fetchDataDimension - visibleDimension) * (1 - _leadingFetchDataRatio);
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
    }
  }
  
  BOOL animate = !_firstLayoutOfRects;
  [UIView animateWithDuration:animate ? 0.3 : 0.0 delay:0.0 options:UIViewAnimationOptionLayoutSubviews animations:^{
    _visibleRect.frame    = CGRectMake(HORIZONTAL_INSET + visiblePoint,    rect.origin.y, visibleDimension,    subCellHeight);
    _displayRect.frame    = CGRectMake(HORIZONTAL_INSET + displayPoint,    rect.origin.y, displayDimension,    subCellHeight);
    _fetchDataRect.frame  = CGRectMake(HORIZONTAL_INSET + fetchDataPoint,  rect.origin.y, fetchDataDimension,  subCellHeight);
  } completion:^(BOOL finished) {}];
  
  if (!animate) {
    _visibleRect.alpha = _displayRect.alpha = _fetchDataRect.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
      _visibleRect.alpha = _displayRect.alpha = _fetchDataRect.alpha = 1;
    }];
  }
  
  _firstLayoutOfRects = NO;
}

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio
                  displayRatio:(CGFloat)displayRatio
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio
                fetchDataRatio:(CGFloat)fetchDataRatio
         leadingFetchDataRatio:(CGFloat)leadingFetchDataRatio
                     direction:(ASScrollDirection)scrollDirection
{
  _visibleRatio = visibleRatio;
  _displayRatio = displayRatio;
  _leadingDisplayRatio = leadingDisplayRatio;
  _fetchDataRatio = fetchDataRatio;
  _leadingFetchDataRatio = leadingFetchDataRatio;
  _scrollDirection = scrollDirection;
  
  [self setNeedsLayout];
}

- (ASTextNode *)createDebugTextNode
{
  ASTextNode *label = [[ASTextNode alloc] init];
  [self addSubnode:label];
  return label;
}

- (void)setBarSubviewOrder
{
  if (_fetchDataRatio == 1.0) {
    [self sendSubviewToBack:_fetchDataRect.view];
  } else {
    [self sendSubviewToBack:_displayRect.view];
  }
  
  [self bringSubviewToFront:_visibleRect.view];
}

- (void)setBarDebugLabelsWithSize:(CGFloat)size
{
  if (!_debugString) {
    _debugString = NSStringFromClass([[_rangeController dataSource] class]);
  }
  if (_debugString) {
    _debugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:_debugString withSize:size];
  }
  
  switch (_scrollDirection) {
    case ASScrollDirectionLeft:
      _leftDebugText.hidden = NO;
      _leftDebugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:@"◀︎" withSize:size];
      _rightDebugText.hidden = YES;
      break;
    case ASScrollDirectionRight:
      _leftDebugText.hidden = YES;
      _rightDebugText.hidden = NO;
      _rightDebugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▶︎" withSize:size];
      break;
    case ASScrollDirectionUp:
      _leftDebugText.hidden = NO;
      _leftDebugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▲" withSize:size];
      _rightDebugText.hidden = YES;
      break;
    case ASScrollDirectionDown:
      _leftDebugText.hidden = YES;
      _rightDebugText.hidden = NO;
      _rightDebugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▼" withSize:size];
      break;
    case ASScrollDirectionNone:
      _leftDebugText.hidden = YES;
      _rightDebugText.hidden = YES;
      break;
    default:
      break;
  }
}

+ (NSAttributedString *)whiteAttributedStringFromString:(NSString *)string withSize:(CGFloat)size
{
  NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor whiteColor],
                               NSFontAttributeName : [UIFont systemFontOfSize:size]};
  return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

+ (UIImage *)resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                             scale:(CGFloat)scale
                                   backgroundColor:(UIColor *)backgroundColor
                                         fillColor:(UIColor *)fillColor
                                       borderColor:(UIColor *)borderColor
{
  static NSCache *__pathCache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __pathCache = [[NSCache alloc] init];
  });
  
  CGFloat dimension   = (cornerRadius * 2) + 1;
  CGRect bounds       = CGRectMake(0, 0, dimension, dimension);
  
  NSNumber *pathKey   = [NSNumber numberWithFloat:cornerRadius];
  UIBezierPath *path  = nil;
  
  @synchronized(__pathCache) {
    path = [__pathCache objectForKey:pathKey];
    if (!path) {
      path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:cornerRadius];
      [__pathCache setObject:path forKey:pathKey];
    }
  }
  
  UIGraphicsBeginImageContextWithOptions(bounds.size, backgroundColor != nil, scale);
  
  if (backgroundColor) {
    [backgroundColor setFill];
    // Copy "blend" mode is extra fast because it disregards any value currently in the buffer and overwrites directly.
    UIRectFillUsingBlendMode(bounds, kCGBlendModeCopy);
  }
  
  [fillColor setFill];
  [path fill];
  
  if (borderColor) {
    [borderColor setStroke];
    
    CGFloat lineWidth = 1.0 / scale;
    CGRect strokeRect = CGRectInset(bounds, lineWidth / 2.0, lineWidth / 2.0);
    
    // It is rarer to have a stroke path, and our cache key only handles rounded rects for the exact-stretchable
    // size calculated by cornerRadius, so we won't bother caching this path.  Profiling validates this decision.
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:cornerRadius];
    [strokePath setLineWidth:lineWidth];
    [strokePath stroke];
  }
  
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIEdgeInsets capInsets = UIEdgeInsetsMake(cornerRadius, cornerRadius, cornerRadius, cornerRadius);
  result = [result resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
  
  return result;
}

@end
