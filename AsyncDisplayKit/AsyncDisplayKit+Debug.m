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

static BOOL __shouldShowImageScalingOverlay = NO;
static BOOL __shouldShowRangeDebugOverlay = NO;

@class _ASRangeDebuggingControllerView;

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
@interface _ASRangeDebuggingOverlayView : UIView
+ (instancetype)sharedInstance;

- (void)addRangeController:(ASRangeController *)rangeController;

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections scrollDirection:(ASScrollDirection)direction rangeMode:(ASLayoutRangeMode)mode tuningParameters:(ASRangeTuningParameters)parameters tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData interfaceState:(ASInterfaceState)interfaceState;

@end

@interface _ASRangeDebuggingControllerView : UIView

@property (nonatomic, weak) ASRangeController *rangeController;
@property (nonatomic, assign) BOOL isVerticalElement;

+ (UIImage *)resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                             scale:(CGFloat)scale
                                   backgroundColor:(UIColor *)backgroundColor
                                         fillColor:(UIColor *)fillColor
                                       borderColor:(UIColor *)borderColor;

- (instancetype)initWithRangeController:(ASRangeController *)rangeController;

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio displayRatio:(CGFloat)displayRatio
                fetchDataRatio:(CGFloat)fetchDataRatio direction:(ASScrollDirection)direction
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio leadingFetchDataRatio:(CGFloat)leadingFetchDataRatio
                    onscreen:(BOOL)onscreen;

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
  [[_ASRangeDebuggingOverlayView sharedInstance] addRangeController:self];
}

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections scrollDirection:(ASScrollDirection)direction rangeMode:(ASLayoutRangeMode)mode tuningParameters:(ASRangeTuningParameters)parameters tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData interfaceState:(ASInterfaceState)interfaceState
{
  [[_ASRangeDebuggingOverlayView sharedInstance] updateRangeController:controller scrollableDirections:scrollableDirections scrollDirection:direction rangeMode:mode tuningParameters:parameters tuningParametersFetchData:parametersFetchData interfaceState:interfaceState];
}


@end


#pragma mark - _ASRangeDebuggingOverlayView

@interface _ASRangeDebuggingOverlayView () <UIGestureRecognizerDelegate>
@end

@implementation _ASRangeDebuggingOverlayView
{
  NSMutableArray *_rangeControllerViews;
}

+ (instancetype)sharedInstance
{
  static _ASRangeDebuggingOverlayView *__rangeDebugOverlay = nil;
  
  if (!__rangeDebugOverlay) {
    __rangeDebugOverlay = [[self alloc] initWithFrame:CGRectZero];
    [[[UIApplication sharedApplication] keyWindow] addSubview:__rangeDebugOverlay];
  }
  
  return __rangeDebugOverlay;
}

#define OVERLAY_VIEW_INSET 20
- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {

    self.backgroundColor        = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    self.layer.zPosition        = 1000;
    
    _rangeControllerViews       = [[NSMutableArray alloc] init];
    
    CGSize windowSize    = [[[UIApplication sharedApplication] keyWindow] bounds].size;
    CGFloat overlayScale = 3.0;
    self.frame           = CGRectMake(windowSize.width - windowSize.width / overlayScale - OVERLAY_VIEW_INSET,
                                     windowSize.height - windowSize.height / overlayScale - OVERLAY_VIEW_INSET,
                                     windowSize.width / overlayScale,
                                     windowSize.height / overlayScale);
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPanned:)];
    [self addGestureRecognizer:panGR];
    
    UIPinchGestureRecognizer *pinchGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPinched:)];
    [self addGestureRecognizer:pinchGR];
  }
  
  return self;
}

#define RANGE_VIEW_THICKNESS 20
#define RANGE_VIEW_BUFFER    0
- (void)layoutSubviews
{
  [super layoutSubviews];

  CGRect boundsRect = self.bounds;
  CGSize boundsSize = boundsRect.size;
  CGRect rect       = CGRectMake(0, boundsSize.height - RANGE_VIEW_THICKNESS, boundsSize.width, RANGE_VIEW_THICKNESS);
  
  CGFloat totalHeight = 0.0;
  
  for (_ASRangeDebuggingControllerView *rangeView in _rangeControllerViews) {
    if (!rangeView.hidden) {
      rangeView.frame  = rect;
      rect.origin.y   -= (rect.size.height + RANGE_VIEW_BUFFER);
      totalHeight     += (rect.size.height + RANGE_VIEW_BUFFER);
    }
  }
  
  totalHeight     -= RANGE_VIEW_BUFFER;
  rect.origin.y   += (rect.size.height + RANGE_VIEW_BUFFER);
  [UIView animateWithDuration:0.2 animations:^{
    self.frame = CGRectMake(self.frame.origin.x,
                             self.frame.origin.y + (boundsSize.height - totalHeight),
                             boundsSize.width,
                             totalHeight);
  }];
}

- (void)addRangeController:(ASRangeController *)rangeController
{
  _ASRangeDebuggingControllerView *rangeView = [[_ASRangeDebuggingControllerView alloc] initWithRangeController:rangeController];
  [_rangeControllerViews addObject:rangeView];
  [self addSubview:rangeView];
  
//  NSLog(@"%@",  NSStringFromClass([yourObject class])
}

- (void)updateRangeController:(ASRangeController *)controller scrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
             tuningParameters:(ASRangeTuningParameters)parameters
    tuningParametersFetchData:(ASRangeTuningParameters)parametersFetchData
               interfaceState:(ASInterfaceState)interfaceState;
{
  _ASRangeDebuggingControllerView *viewToUpdate = nil;
  
  // reverse object enumerator so that I can delete things
  NSInteger numViews = [_rangeControllerViews count] - 1;
  for (NSInteger i = numViews; i > -1; i--) {
    
    _ASRangeDebuggingControllerView *rangeView = [_rangeControllerViews objectAtIndex:i];
    
    // rangeController has been deleted
    if (!rangeView.rangeController) {
      [[_rangeControllerViews objectAtIndex:i] removeFromSuperview];
      [_rangeControllerViews removeObjectAtIndex:i];
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

  BOOL onScreen;
  if (interfaceState & ASInterfaceStateVisible) {
    onScreen = YES;
  }
  
  NSLog(@"%lu", (long)interfaceState);
//  
//  // FIXME: hack to remove mysterious all green bars
//  //  if (visibleRatio == 1) {
//  if (direction == ASScrollDirectionNone) {
//    viewToUpdate.hidden = YES;
//  }

  [viewToUpdate updateWithVisibleRatio:visibleRatio displayRatio:displayRatio
                        fetchDataRatio:fetchDataRatio direction:direction leadingDisplayRatio:leadingDisplayTuningRatio leadingFetchDataRatio:leadingFetchDataTuningRatio onscreen:YES];
//
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

- (void)rangeDebugOverlayWasPinched:(UIPinchGestureRecognizer *)recognizer
{
  recognizer.view.transform = CGAffineTransformScale(recognizer.view.transform, recognizer.scale, recognizer.scale);
  recognizer.scale = 1;
}

@end

#pragma mark - _ASRangeDebuggingControllerView


@implementation _ASRangeDebuggingControllerView
{
  UIImageView       *_visibleRect;      // FIXME: should we make these ASImageNodes / ASTextNodes?
  UIImageView       *_displayRect;
  UIImageView       *_fetchDataRect;
  UILabel           *_debugLabel;
  UILabel           *_leftDebugLabel;
  UILabel           *_rightDebugLabel;
  CGFloat           _visibleRatio;
  CGFloat           _displayRatio;
  CGFloat           _fetchDataRatio;
  CGFloat           _leadingDisplayRatio;
  CGFloat           _leadingFetchDataRatio;
  BOOL              _onScreen;
  ASScrollDirection _direction;
}


- (instancetype)initWithRangeController:(ASRangeController *)rangeController
{
  self = [super initWithFrame:CGRectZero];
 
  if (self) {
    
    _rangeController = rangeController;
    _debugLabel      = [self createDebugLabel];
    _leftDebugLabel  = [self createDebugLabel];
    _rightDebugLabel = [self createDebugLabel];
    [self addSubview:_debugLabel];
    [self addSubview:_leftDebugLabel];
    [self addSubview:_rightDebugLabel];
  
    _fetchDataRect = [[UIImageView alloc] init];
    _fetchDataRect.image = [_ASRangeDebuggingControllerView resizableRoundedImageWithCornerRadius:3
                                                                                            scale:[[UIScreen mainScreen] scale]
                                                                                  backgroundColor:nil
                                                                                        fillColor:[[UIColor orangeColor] colorWithAlphaComponent:0.5]
                                                                                      borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
    [self addSubview:_fetchDataRect];
    
    _visibleRect = [[UIImageView alloc] init];
    _visibleRect.image = [_ASRangeDebuggingControllerView resizableRoundedImageWithCornerRadius:3
                                                                                          scale:[[UIScreen mainScreen] scale]
                                                                                backgroundColor:nil
                                                                                      fillColor:[[UIColor greenColor] colorWithAlphaComponent:0.5]
                                                                                    borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
    [self addSubview:_visibleRect];
    
    _displayRect = [[UIImageView alloc] init];
    _displayRect.image = [_ASRangeDebuggingControllerView resizableRoundedImageWithCornerRadius:3
                                                                                          scale:[[UIScreen mainScreen] scale]
                                                                                backgroundColor:nil
                                                                                      fillColor:[[UIColor yellowColor] colorWithAlphaComponent:0.5]
                                                                                    borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]];
  [self addSubview:_displayRect];
  }
  
  return self;
}

- (UILabel *)createDebugLabel
{
  UILabel *label = [[UILabel alloc] init];
  label.textColor = [UIColor whiteColor];
  return label;
}

#define HORIZONTAL_INSET 10
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  _debugLabel.text = _onScreen ? @"onScreen" : @"";
  
  CGSize boundsSize = self.bounds.size;
  [_debugLabel sizeToFit];
  CGRect rect       = CGRectIntegral(CGRectMake(0, 0, boundsSize.width, boundsSize.height / 2.0));
  rect.size         = _debugLabel.frame.size;
  rect.origin.x     = (boundsSize.width - _debugLabel.frame.size.width) / 2.0;
  _debugLabel.frame = rect;
  _debugLabel.font  = [UIFont systemFontOfSize:floorf(boundsSize.height / 2.0)-1];
  rect.origin.y    += rect.size.height;
  
  rect.origin.x          = 0;
  rect.size              = CGSizeMake(HORIZONTAL_INSET, boundsSize.height / 2.0);
  _leftDebugLabel.frame  = rect;
  _leftDebugLabel.font   = [UIFont systemFontOfSize:floorf(boundsSize.height / 2.0)-1];

  rect.origin.x          = boundsSize.width - HORIZONTAL_INSET;
  _rightDebugLabel.frame = rect;
  _rightDebugLabel.font  = [UIFont systemFontOfSize:floorf(boundsSize.height / 2.0)-1];


  CGFloat visibleDimension   = (boundsSize.width - 2 * HORIZONTAL_INSET) * _visibleRatio;
  CGFloat displayDimension   = (boundsSize.width - 2 * HORIZONTAL_INSET) * _displayRatio;
  CGFloat fetchDataDimension = (boundsSize.width - 2 * HORIZONTAL_INSET) * _fetchDataRatio;
  CGFloat visiblePoint = 0;
  CGFloat displayPoint = 0;
  CGFloat fetchDataPoint = 0;
  
  [self setScrollDirectionDebugLabels];
  [self setFetchDataDisplaySubviewOrder];
  [self setAlphaForRatios];
  
  if (ASScrollDirectionContainsLeft(_direction) || ASScrollDirectionContainsUp(_direction)) {
    
    if (_displayRatio == 1.0) {
      [[self superview] insertSubview:_displayRect belowSubview:_fetchDataRect];
      visiblePoint        = (displayDimension - visibleDimension) * _leadingDisplayRatio;
      fetchDataPoint      = visiblePoint - (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
    } else {
      visiblePoint        = (fetchDataDimension - visibleDimension) * _leadingFetchDataRatio;
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * _leadingDisplayRatio;
    }
  } else if (ASScrollDirectionContainsRight(_direction) || ASScrollDirectionContainsDown(_direction)) {
    
    if (_displayRatio == 1.0) {
      
      visiblePoint        = (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
      fetchDataPoint      = visiblePoint - (fetchDataDimension - visibleDimension) * (1 - _leadingFetchDataRatio);
    } else {
      visiblePoint        = (fetchDataDimension - visibleDimension) * (1 - _leadingFetchDataRatio);
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
    }
  }
  
  BOOL animate = !CGRectEqualToRect(CGRectMake(0, 0, 10, 0), _visibleRect.frame);
  
  [UIView animateWithDuration:animate ? 0.3 : 0.0 animations:^{
    _visibleRect.frame    = CGRectMake(HORIZONTAL_INSET + visiblePoint,    rect.origin.y, visibleDimension,    10);
    _displayRect.frame    = CGRectMake(HORIZONTAL_INSET + displayPoint,    rect.origin.y, displayDimension,    10);
    _fetchDataRect.frame  = CGRectMake(HORIZONTAL_INSET + fetchDataPoint,  rect.origin.y, fetchDataDimension,  10);
  }];
  
  if (!animate) {
    _visibleRect.alpha = _displayRect.alpha = _fetchDataRect.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
      _visibleRect.alpha = _displayRect.alpha = _fetchDataRect.alpha = 1;
    }];
  }
}

- (void)setAlphaForRatios
{
  if ((_fetchDataRatio == _displayRatio) && (_visibleRatio == _displayRatio)) {
    self.alpha = 0.5;
  } else {
    self.alpha = 1;
  }
}

- (void)setFetchDataDisplaySubviewOrder
{
  if (_fetchDataRatio == 1.0) {
    [self sendSubviewToBack:_fetchDataRect];
  } else {
    [self sendSubviewToBack:_displayRect];
  }
  [self bringSubviewToFront:_visibleRect];
}

- (void)setScrollDirectionDebugLabels
{
  switch (_direction) {
    case ASScrollDirectionLeft:
      _leftDebugLabel.hidden  = NO;
      _leftDebugLabel.text    = @"◀︎";
      _rightDebugLabel.hidden = YES;
      break;
    case ASScrollDirectionRight:
      _leftDebugLabel.hidden  = YES;
      _rightDebugLabel.hidden = NO;
      _rightDebugLabel.text    = @"▶︎";
      break;
    case ASScrollDirectionUp:
      _leftDebugLabel.hidden  = NO;
      _leftDebugLabel.text    = @"▲";
      _rightDebugLabel.hidden = YES;
      break;
    case ASScrollDirectionDown:
      _leftDebugLabel.hidden  = YES;
      _rightDebugLabel.hidden = NO;
      _rightDebugLabel.text    = @"▼";
      break;
    case ASScrollDirectionNone:
      _leftDebugLabel.hidden  = YES;
      _rightDebugLabel.hidden = YES;
      break;
    default:
      break;
  }
}

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio displayRatio:(CGFloat)displayRatio
                fetchDataRatio:(CGFloat)fetchDataRatio direction:(ASScrollDirection)direction
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio leadingFetchDataRatio:(CGFloat)leadingFetchDataRatio onscreen:(BOOL)onscreen
{
  _direction = direction;
  _visibleRatio = visibleRatio;
  _displayRatio = displayRatio;
  _fetchDataRatio = fetchDataRatio;
  _leadingFetchDataRatio = leadingFetchDataRatio;
  _leadingDisplayRatio = leadingDisplayRatio;
  _onScreen = YES;
  self.isVerticalElement = ASScrollDirectionContainsVerticalDirection(direction);
  
  [self setNeedsLayout];
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
