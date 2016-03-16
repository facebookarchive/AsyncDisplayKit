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

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections scrollDirection:(ASScrollDirection)direction rangeMode:(ASLayoutRangeMode)mode tuningParameters:(ASRangeTuningParameters)parameters tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData interfaceState:(ASInterfaceState)interfaceState;

@end

@interface _ASRangeDebugBarView : UIView

@property (nonatomic, weak) ASRangeController *rangeController;

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
                     direction:(ASScrollDirection)direction
                      onscreen:(BOOL)onscreen;

- (void)adjustFrameWithYOffset:(CGFloat)offset;

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

- (void)addRangeControllerToRangeDebugOverlay
{
  [[_ASRangeDebugOverlayView sharedInstance] addRangeController:self];
}

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections scrollDirection:(ASScrollDirection)direction rangeMode:(ASLayoutRangeMode)mode tuningParameters:(ASRangeTuningParameters)parameters tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData interfaceState:(ASInterfaceState)interfaceState
{
  [[_ASRangeDebugOverlayView sharedInstance] updateRangeController:controller scrollableDirections:scrollableDirections scrollDirection:direction rangeMode:mode tuningParameters:parameters tuningParametersFetchData:parametersFetchData interfaceState:interfaceState];
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
}

+ (instancetype)sharedInstance
{
  static _ASRangeDebugOverlayView *__rangeDebugOverlay = nil;
  
  if (!__rangeDebugOverlay) {
    __rangeDebugOverlay = [[self alloc] initWithFrame:CGRectZero];
    [[[UIApplication sharedApplication] keyWindow] addSubview:__rangeDebugOverlay];
  }
  
  return __rangeDebugOverlay;
}

#define OVERLAY_INSET 20
#define OVERLAY_SCALE 3
- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
    _rangeControllerViews = [[NSMutableArray alloc] init];
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    self.layer.zPosition = 1000;
    self.clipsToBounds = YES;
    
    CGSize windowSize = [[[UIApplication sharedApplication] keyWindow] bounds].size;
    self.frame  = CGRectMake(windowSize.width - windowSize.width / OVERLAY_SCALE - OVERLAY_INSET,
                            windowSize.height - windowSize.height / OVERLAY_SCALE - OVERLAY_INSET,
                            windowSize.width / OVERLAY_SCALE,
                            windowSize.height / OVERLAY_SCALE);
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPanned:)];
    [self addGestureRecognizer:panGR];
    
//    UIPinchGestureRecognizer *pinchGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPinched:)];
//    [self addGestureRecognizer:pinchGR];
  }
  
  return self;
}

#define BAR_THICKNESS 20
#define BARS_INSET    5
- (void)layoutSubviews
{
  [super layoutSubviews];

//  CGRect boundsRect = self.bounds;
//  CGSize boundsSize = boundsRect.size;
//  CGRect rect = CGRectMake(0, boundsSize.height - BARS_INSET - BAR_THICKNESS, boundsSize.width, BAR_THICKNESS);
//  CGFloat totalHeight = BARS_INSET;
//  
//  // position top one at negative y (only if new)
////  - addRange instance variable +++
////  set to zero below totalHeight
////  work top down
////  method add frame with y offset
////  then in animation offset, change back lower (multiple of ++)
//  // deal with subtraction?
//  
//  for (_ASRangeDebugBarView *rangeView in _rangeControllerViews) {
//    if (!rangeView.hidden) {
//      rangeView.frame  = rect;
//      rect.origin.y   -= rect.size.height;
//      totalHeight     += rect.size.height;
//    }
//  }
//  
//  
//  [UIView animateWithDuration:0.2 animations:^{
//    self.frame = CGRectMake(self.frame.origin.x,
//                            self.frame.origin.y + (boundsSize.height - totalHeight),
//                            boundsSize.width,
//                            totalHeight); }];

  CGRect boundsRect = self.bounds;
  CGSize boundsSize = boundsRect.size;
  CGRect rect = CGRectMake(0, 0, boundsSize.width, BAR_THICKNESS);
  CGFloat totalHeight = BARS_INSET;
  
  _ASRangeDebugBarView *rangeView;
  NSInteger numViews = [_rangeControllerViews count] - 1;
  for (NSInteger i = numViews; i > -1; i--) {
    rangeView = [_rangeControllerViews objectAtIndex:i];
    if (!rangeView.hidden) {
      rangeView.frame  = rect;
      rect.origin.y   += BAR_THICKNESS;
      totalHeight     += BAR_THICKNESS;
    }
  }
  
  rect.origin.y += BARS_INSET;
  totalHeight   += BARS_INSET;

  [UIView animateWithDuration:0.2 animations:^{
    self.frame = CGRectMake(self.frame.origin.x,
                             self.frame.origin.y - _newControllerCount * BAR_THICKNESS,
                             boundsSize.width,
                             totalHeight);
    
    for (_ASRangeDebugBarView *rangeView in _rangeControllerViews) {
      if (!rangeView.hidden) {
        CGFloat finalYOffsetAdjustment = _newControllerCount * BAR_THICKNESS;
        [rangeView adjustFrameWithYOffset:finalYOffsetAdjustment];
      }
    }
  }];
  
  _newControllerCount = 0;
  _removeControllerCount = 0;
}

- (void)addRangeController:(ASRangeController *)rangeController
{
  _ASRangeDebugBarView *rangeView = [[_ASRangeDebugBarView alloc] initWithRangeController:rangeController];
  [_rangeControllerViews addObject:rangeView];
  [self addSubview:rangeView];
  _newControllerCount++;
}

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
             tuningParameters:(ASRangeTuningParameters)parameters
    tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData
               interfaceState:(ASInterfaceState)interfaceState;
{
  _ASRangeDebugBarView *viewToUpdate = nil;
  
  // reverse object enumerator so that I can delete things
  NSInteger numViews = [_rangeControllerViews count] - 1;
  for (NSInteger i = numViews; i > -1; i--) {
    
    _ASRangeDebugBarView *rangeView = [_rangeControllerViews objectAtIndex:i];
    
    // rangeController has been deleted
    if (!rangeView.rangeController) {
      [[_rangeControllerViews objectAtIndex:i] removeFromSuperview];
      [_rangeControllerViews removeObjectAtIndex:i];
      _removeControllerCount++;
    }
    
    if ([rangeView.rangeController isEqual:controller]) {
      viewToUpdate = rangeView;
    }
  }
  
  // assume fetch data is largest = self.bounds
  CGRect boundsRect = self.bounds;
  CGRect visibleRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, ASRangeTuningParametersZero, scrollableDirections, direction);
  CGRect displayRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, parameters, scrollableDirections, direction);
  CGRect fetchDataRect = CGRectExpandToRangeWithScrollableDirections(boundsRect, parametersFetchData, scrollableDirections, direction);
  
  // figure out which is biggest and assume that is full bounds
  BOOL displayRangeLargerThanFetch    = NO;
  CGFloat visibleRatio                = 0;
  CGFloat displayRatio                = 0;
  CGFloat fetchDataRatio              = 0;
  CGFloat leadingDisplayTuningRatio   = 0;
  CGFloat leadingFetchDataTuningRatio = 0;

  if (!((parameters.leadingBufferScreenfuls + parameters.trailingBufferScreenfuls) == 0)) {
    leadingDisplayTuningRatio = parameters.leadingBufferScreenfuls / (parameters.leadingBufferScreenfuls + parameters.trailingBufferScreenfuls);
  }
  if (!((parametersFetchData.leadingBufferScreenfuls + parametersFetchData.trailingBufferScreenfuls) == 0)) {
    leadingFetchDataTuningRatio = parametersFetchData.leadingBufferScreenfuls / (parametersFetchData.leadingBufferScreenfuls + parametersFetchData.trailingBufferScreenfuls);
  }
  
  if (ASScrollDirectionContainsVerticalDirection(direction)) {
    
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

  BOOL onScreen = (interfaceState & ASInterfaceStateVisible) ? YES : NO;

  [viewToUpdate updateWithVisibleRatio:visibleRatio
                          displayRatio:displayRatio
                   leadingDisplayRatio:leadingDisplayTuningRatio
                        fetchDataRatio:fetchDataRatio
                 leadingFetchDataRatio:leadingFetchDataTuningRatio
                             direction:direction
                              onscreen:onScreen];

  [self setNeedsLayout];
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
  ASScrollDirection _direction;
  BOOL              _onScreen;
  BOOL              _firstLayoutOfRects;
}

- (instancetype)initWithRangeController:(ASRangeController *)rangeController
{
  self = [super initWithFrame:CGRectZero];
 
  if
    (self) {
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
  CGFloat subCellHeight = floorf(boundsSize.height / 2.0)-1;
  [self setBarDebugLabelsWithSize:subCellHeight];
  [self setBarSubviewOrder];
  [self setBarAlpha];

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
  
  if (ASScrollDirectionContainsLeft(_direction) || ASScrollDirectionContainsUp(_direction)) {
    
    if (displayLargerThanFetchData) {
      visiblePoint        = (displayDimension - visibleDimension) * _leadingDisplayRatio;
      fetchDataPoint      = visiblePoint - (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
    } else {
      visiblePoint        = (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * _leadingDisplayRatio;
    }
  } else if (ASScrollDirectionContainsRight(_direction) || ASScrollDirectionContainsDown(_direction)) {
    
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
                     direction:(ASScrollDirection)direction
                      onscreen:(BOOL)onscreen
{
  _visibleRatio = visibleRatio;
  _displayRatio = displayRatio;
  _leadingDisplayRatio = leadingDisplayRatio;
  _fetchDataRatio = fetchDataRatio;
  _leadingFetchDataRatio = leadingFetchDataRatio;
  _direction = direction;
  _onScreen = YES;
  
  [self setNeedsLayout];
}
      
- (void)adjustFrameWithYOffset:(CGFloat)offset
{
  CGRect newFrame = self.frame;
  newFrame.origin = CGPointMake(newFrame.origin.x, newFrame.origin.y + offset);
  self.frame = newFrame;
}

- (ASTextNode *)createDebugTextNode
{
  ASTextNode *label = [[ASTextNode alloc] init];
  [self addSubnode:label];
  return label;
}

- (void)setBarAlpha
{
  self.alpha = ((_fetchDataRatio == _displayRatio) && (_visibleRatio == _displayRatio)) ? 0.5 : 1;
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
  if (_onScreen) {
    NSString *dataSourceClassString = NSStringFromClass([[[self rangeController] dataSource] class]);
    _debugText.attributedString = [_ASRangeDebugBarView whiteAttributedStringFromString:dataSourceClassString withSize:size];
  }
  
  switch (_direction) {
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
