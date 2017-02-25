//
//  AsyncDisplayKit+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASWeakSet.h>
#import <AsyncDisplayKit/UIImage+ASConvenience.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASRangeController.h>


#pragma mark - ASImageNode (Debugging)

static BOOL __shouldShowImageScalingOverlay = NO;

@implementation ASImageNode (Debugging)

+ (void)setShouldShowImageScalingOverlay:(BOOL)show;
{
  __shouldShowImageScalingOverlay = show;
}

+ (BOOL)shouldShowImageScalingOverlay
{
  return __shouldShowImageScalingOverlay;
}

@end

#pragma mark - ASControlNode (DebuggingInternal)

static BOOL __enableHitTestDebug = NO;

@interface ASControlNode (DebuggingInternal)

- (ASImageNode *)debugHighlightOverlay;

@end

@implementation ASControlNode (Debugging)

+ (void)setEnableHitTestDebug:(BOOL)enable
{
  __enableHitTestDebug = enable;
}

+ (BOOL)enableHitTestDebug
{
  return __enableHitTestDebug;
}

// layout method required ONLY when hitTestDebug is enabled
- (void)layout
{
  [super layout];
  
  if ([ASControlNode enableHitTestDebug]) {
    
    // Construct hitTestDebug highlight overlay frame indicating tappable area of a node, which can be restricted by two things:
    
    // (1) Any parent's tapable area (its own bounds + hitTestSlop) may restrict the desired tappable area expansion using
    // hitTestSlop of a child as UIKit event delivery (hitTest:) will not search sub-hierarchies if one of our parents does
    // not return YES for pointInside:. To circumvent this restriction, a developer will need to set / adjust the hitTestSlop
    // on the limiting parent. This is indicated in the overlay by a dark GREEN edge. This is an ACTUAL restriction.
    
    // (2) Any parent's .clipToBounds. If a parent is clipping, we cannot show the overlay outside that area
    // (although it still respond to touch). To indicate that the overlay cannot accurately display the true tappable area,
    // the overlay will have an ORANGE edge. This is a VISUALIZATION restriction.
    
    CGRect intersectRect                 = UIEdgeInsetsInsetRect(self.bounds, [self hitTestSlop]);
    UIRectEdge clippedEdges              = UIRectEdgeNone;
    UIRectEdge clipsToBoundsClippedEdges = UIRectEdgeNone;
    CALayer *layer               = self.layer;
    CALayer *intersectLayer      = layer;
    CALayer *intersectSuperlayer = layer.superlayer;
    
    // FIXED: Stop climbing hierarchy if UIScrollView is encountered (its offset bounds origin may make it seem like our events
    // will be clipped when scrolling will actually reveal them (because this process will not re-run due to scrolling))
    while (intersectSuperlayer && ![intersectSuperlayer.delegate respondsToSelector:@selector(contentOffset)]) {
      
      // Get parent's tappable area
      CGRect parentHitRect     = intersectSuperlayer.bounds;
      BOOL parentClipsToBounds = NO;
      
      // If parent is a node, tappable area may be expanded by hitTestSlop
      ASDisplayNode *parentNode = ASLayerToDisplayNode(intersectSuperlayer);
      if (parentNode) {
        UIEdgeInsets parentSlop = [parentNode hitTestSlop];
        
        // If parent has hitTestSlop, expand tappable area (if parent doesn't clipToBounds)
        if (!UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, parentSlop)) {
          parentClipsToBounds = parentNode.clipsToBounds;
          if (!parentClipsToBounds) {
            parentHitRect = UIEdgeInsetsInsetRect(parentHitRect, [parentNode hitTestSlop]);
          }
        }
      }
      
      // Convert our current rect to parent coordinates
      CGRect intersectRectInParentCoordinates = [intersectSuperlayer convertRect:intersectRect fromLayer:intersectLayer];
      
      // Intersect rect with the parent's tappable area rect
      intersectRect = CGRectIntersection(parentHitRect, intersectRectInParentCoordinates);
      if (!CGSizeEqualToSize(parentHitRect.size, intersectRectInParentCoordinates.size)) {
        clippedEdges = [self setEdgesOfIntersectionForChildRect:intersectRectInParentCoordinates
                                                     parentRect:parentHitRect rectEdge:clippedEdges];
        if (parentClipsToBounds) {
          clipsToBoundsClippedEdges = [self setEdgesOfIntersectionForChildRect:intersectRectInParentCoordinates
                                                                    parentRect:parentHitRect rectEdge:clipsToBoundsClippedEdges];
        }
      }
      
      // move up hierarchy
      intersectLayer      = intersectSuperlayer;
      intersectSuperlayer = intersectLayer.superlayer;
    }
    
    // produce final overlay image (or fill background if edges aren't restricted)
    CGRect finalRect   = [intersectLayer convertRect:intersectRect toLayer:layer];
    UIColor *fillColor = [[UIColor greenColor] colorWithAlphaComponent:0.4];
    
    ASImageNode *debugOverlay = [self debugHighlightOverlay];
    
    // determine if edges are clipped and if so, highlight the restricted edges
    if (clippedEdges == UIRectEdgeNone) {
      debugOverlay.backgroundColor = fillColor;
    } else {
      const CGFloat borderWidth = 2.0;
      UIColor *borderColor      = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
      UIColor *clipsBorderColor = [UIColor colorWithRed:30/255.0 green:90/255.0 blue:50/255.0 alpha:0.7];
      CGRect imgRect            = CGRectMake(0, 0, 2.0 * borderWidth + 1.0, 2.0 * borderWidth + 1.0);
      
      UIGraphicsBeginImageContext(imgRect.size);
      
      [fillColor setFill];
      UIRectFill(imgRect);
      
      [self drawEdgeIfClippedWithEdges:clippedEdges color:clipsBorderColor borderWidth:borderWidth imgRect:imgRect];
      [self drawEdgeIfClippedWithEdges:clipsToBoundsClippedEdges color:borderColor borderWidth:borderWidth imgRect:imgRect];
      
      UIImage *debugHighlightImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      
      UIEdgeInsets edgeInsets = UIEdgeInsetsMake(borderWidth, borderWidth, borderWidth, borderWidth);
      debugOverlay.image = [debugHighlightImage resizableImageWithCapInsets:edgeInsets resizingMode:UIImageResizingModeStretch];
      debugOverlay.backgroundColor = nil;
    }
    
    debugOverlay.frame = finalRect;
  }
}

- (UIRectEdge)setEdgesOfIntersectionForChildRect:(CGRect)childRect parentRect:(CGRect)parentRect rectEdge:(UIRectEdge)rectEdge
{
  // determine which edges of childRect are outside parentRect (and thus will be clipped)
  if (childRect.origin.y < parentRect.origin.y) {
    rectEdge |= UIRectEdgeTop;
  }
  if (childRect.origin.x < parentRect.origin.x) {
    rectEdge |= UIRectEdgeLeft;
  }
  if (CGRectGetMaxY(childRect) > CGRectGetMaxY(parentRect)) {
    rectEdge |= UIRectEdgeBottom;
  }
  if (CGRectGetMaxX(childRect) > CGRectGetMaxX(parentRect)) {
    rectEdge |= UIRectEdgeRight;
  }
  
  return rectEdge;
}

- (void)drawEdgeIfClippedWithEdges:(UIRectEdge)rectEdge color:(UIColor *)color borderWidth:(CGFloat)borderWidth imgRect:(CGRect)imgRect
{
  [color setFill];
  
  // highlight individual edges of overlay if edge is restricted by parentRect
  // so that the developer is aware that increasing hitTestSlop will not result in an expanded tappable area
  if (rectEdge & UIRectEdgeTop) {
    UIRectFill(CGRectMake(0.0, 0.0, imgRect.size.width, borderWidth));
  }
  if (rectEdge & UIRectEdgeLeft) {
    UIRectFill(CGRectMake(0.0, 0.0, borderWidth, imgRect.size.height));
  }
  if (rectEdge & UIRectEdgeBottom) {
    UIRectFill(CGRectMake(0.0, imgRect.size.height - borderWidth, imgRect.size.width, borderWidth));
  }
  if (rectEdge & UIRectEdgeRight) {
    UIRectFill(CGRectMake(imgRect.size.width - borderWidth, 0.0, borderWidth, imgRect.size.height));
  }
}

@end

#pragma mark - ASRangeController (Debugging)

@interface _ASRangeDebugOverlayView : UIView

+ (instancetype)sharedInstance;

- (void)addRangeController:(ASRangeController *)rangeController;

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
      preloadTuningParameters:(ASRangeTuningParameters)preloadTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;

@end

@interface _ASRangeDebugBarView : UIView

@property (nonatomic, weak) ASRangeController *rangeController;
@property (nonatomic, assign) BOOL destroyOnLayout;
@property (nonatomic, strong) NSString *debugString;

- (instancetype)initWithRangeController:(ASRangeController *)rangeController;

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio
                  displayRatio:(CGFloat)displayRatio
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio
                  preloadRatio:(CGFloat)preloadRatio
           leadingpreloadRatio:(CGFloat)leadingpreloadRatio
                     direction:(ASScrollDirection)direction;

@end

static BOOL __shouldShowRangeDebugOverlay = NO;

@implementation ASDisplayNode (RangeDebugging)

+ (void)setShouldShowRangeDebugOverlay:(BOOL)show
{
  __shouldShowRangeDebugOverlay = show;
}

+ (BOOL)shouldShowRangeDebugOverlay
{
  return __shouldShowRangeDebugOverlay;
}

@end

@implementation ASRangeController (DebugInternal)

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
      preloadTuningParameters:(ASRangeTuningParameters)preloadTuningParameters
               interfaceState:(ASInterfaceState)interfaceState
{
  [[_ASRangeDebugOverlayView sharedInstance] updateRangeController:controller
                                          withScrollableDirections:scrollableDirections
                                                   scrollDirection:direction
                                                         rangeMode:mode
                                           displayTuningParameters:displayTuningParameters
                                           preloadTuningParameters:preloadTuningParameters
                                                    interfaceState:interfaceState];
}

@end


#pragma mark _ASRangeDebugOverlayView

@interface _ASRangeDebugOverlayView () <UIGestureRecognizerDelegate>
@end

@implementation _ASRangeDebugOverlayView
{
  NSMutableArray *_rangeControllerViews;
  NSInteger      _newControllerCount;
  NSInteger      _removeControllerCount;
  BOOL           _animating;
}

+ (UIWindow *)keyWindow
{
  // hack to work around app extensions not having UIApplication...not sure of a better way to do this?
  return [[NSClassFromString(@"UIApplication") sharedApplication] keyWindow];
}

+ (instancetype)sharedInstance
{
  static _ASRangeDebugOverlayView *__rangeDebugOverlay = nil;
  
  if (!__rangeDebugOverlay && ASDisplayNode.shouldShowRangeDebugOverlay) {
    __rangeDebugOverlay = [[self alloc] initWithFrame:CGRectZero];
    [[self keyWindow] addSubview:__rangeDebugOverlay];
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
    
    CGSize windowSize = [[[self class] keyWindow] bounds].size;
    self.frame  = CGRectMake(windowSize.width - (windowSize.width / OVERLAY_SCALE) - OVERLAY_INSET, windowSize.height - OVERLAY_INSET,
                                                 windowSize.width / OVERLAY_SCALE, 0.0);
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rangeDebugOverlayWasPanned:)];
    [self addGestureRecognizer:panGR];
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
      preloadTuningParameters:(ASRangeTuningParameters)preloadTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;
{
  _ASRangeDebugBarView *viewToUpdate = [self barViewForRangeController:controller];
  
  CGRect boundsRect = self.bounds;
  CGRect visibleRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, ASRangeTuningParametersZero, scrollableDirections, scrollDirection);
  CGRect displayRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, displayTuningParameters,     scrollableDirections, scrollDirection);
  CGRect preloadRect   = CGRectExpandToRangeWithScrollableDirections(boundsRect, preloadTuningParameters,   scrollableDirections, scrollDirection);
  
  // figure out which is biggest and assume that is full bounds
  BOOL displayRangeLargerThanPreload  = NO;
  CGFloat visibleRatio                = 0;
  CGFloat displayRatio                = 0;
  CGFloat preloadRatio                = 0;
  CGFloat leadingDisplayTuningRatio   = 0;
  CGFloat leadingPreloadTuningRatio   = 0;

  if (!((displayTuningParameters.leadingBufferScreenfuls + displayTuningParameters.trailingBufferScreenfuls) == 0)) {
    leadingDisplayTuningRatio = displayTuningParameters.leadingBufferScreenfuls / (displayTuningParameters.leadingBufferScreenfuls + displayTuningParameters.trailingBufferScreenfuls);
  }
  if (!((preloadTuningParameters.leadingBufferScreenfuls + preloadTuningParameters.trailingBufferScreenfuls) == 0)) {
    leadingPreloadTuningRatio = preloadTuningParameters.leadingBufferScreenfuls / (preloadTuningParameters.leadingBufferScreenfuls + preloadTuningParameters.trailingBufferScreenfuls);
  }
  
  if (ASScrollDirectionContainsVerticalDirection(scrollDirection)) {
    
    if (displayRect.size.height >= preloadRect.size.height) {
      displayRangeLargerThanPreload = YES;
    } else {
      displayRangeLargerThanPreload = NO;
    }
    
    if (displayRangeLargerThanPreload) {
      visibleRatio    = visibleRect.size.height / displayRect.size.height;
      displayRatio    = 1.0;
      preloadRatio    = preloadRect.size.height / displayRect.size.height;
    } else {
      visibleRatio    = visibleRect.size.height / preloadRect.size.height;
      displayRatio    = displayRect.size.height / preloadRect.size.height;
      preloadRatio    = 1.0;
    }

  } else {
    
    if (displayRect.size.width >= preloadRect.size.width) {
      displayRangeLargerThanPreload = YES;
    } else {
      displayRangeLargerThanPreload = NO;
    }
    
    if (displayRangeLargerThanPreload) {
      visibleRatio    = visibleRect.size.width / displayRect.size.width;
      displayRatio    = 1.0;
      preloadRatio    = preloadRect.size.width / displayRect.size.width;
    } else {
      visibleRatio    = visibleRect.size.width / preloadRect.size.width;
      displayRatio    = displayRect.size.width / preloadRect.size.width;
      preloadRatio    = 1.0;
    }
  }

  [viewToUpdate updateWithVisibleRatio:visibleRatio
                          displayRatio:displayRatio
                   leadingDisplayRatio:leadingDisplayTuningRatio
                          preloadRatio:preloadRatio
                   leadingpreloadRatio:leadingPreloadTuningRatio
                             direction:scrollDirection];

  [self setNeedsLayout];
}

- (_ASRangeDebugBarView *)barViewForRangeController:(ASRangeController *)controller
{
  _ASRangeDebugBarView *rangeControllerBarView = nil;
  
  for (_ASRangeDebugBarView *rangeView in [[_rangeControllerViews reverseObjectEnumerator] allObjects]) {
    // remove barView if its rangeController has been deleted
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

@end

#pragma mark _ASRangeDebugBarView

@implementation _ASRangeDebugBarView
{
  ASTextNode        *_debugText;
  ASTextNode        *_leftDebugText;
  ASTextNode        *_rightDebugText;
  ASImageNode       *_visibleRect;
  ASImageNode       *_displayRect;
  ASImageNode       *_preloadRect;
  CGFloat           _visibleRatio;
  CGFloat           _displayRatio;
  CGFloat           _preloadRatio;
  CGFloat           _leadingDisplayRatio;
  CGFloat           _leadingpreloadRatio;
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
    _preloadRect        = [self createRangeNodeWithColor:[UIColor orangeColor]];
    _displayRect        = [self createRangeNodeWithColor:[UIColor yellowColor]];
    _visibleRect        = [self createRangeNodeWithColor:[UIColor greenColor]];
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
  rect.size         = [_debugText layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX))].size;
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
  CGFloat preloadDimension   = (boundsSize.width - 2 * HORIZONTAL_INSET) * _preloadRatio;
  CGFloat visiblePoint       = 0;
  CGFloat displayPoint       = 0;
  CGFloat preloadPoint       = 0;
  
  BOOL displayLargerThanPreload = (_displayRatio == 1.0) ? YES : NO;
  
  if (ASScrollDirectionContainsLeft(_scrollDirection) || ASScrollDirectionContainsUp(_scrollDirection)) {
    
    if (displayLargerThanPreload) {
      visiblePoint        = (displayDimension - visibleDimension) * _leadingDisplayRatio;
      preloadPoint        = visiblePoint - (preloadDimension - visibleDimension) * _leadingpreloadRatio;
    } else {
      visiblePoint        = (preloadDimension - visibleDimension) * _leadingpreloadRatio;
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * _leadingDisplayRatio;
    }
  } else if (ASScrollDirectionContainsRight(_scrollDirection) || ASScrollDirectionContainsDown(_scrollDirection)) {
    
    if (displayLargerThanPreload) {
      visiblePoint        = (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
      preloadPoint        = visiblePoint - (preloadDimension - visibleDimension) * (1 - _leadingpreloadRatio);
    } else {
      visiblePoint        = (preloadDimension - visibleDimension) * (1 - _leadingpreloadRatio);
      displayPoint        = visiblePoint - (displayDimension - visibleDimension) * (1 - _leadingDisplayRatio);
    }
  }
  
  BOOL animate = !_firstLayoutOfRects;
  [UIView animateWithDuration:animate ? 0.3 : 0.0 delay:0.0 options:UIViewAnimationOptionLayoutSubviews animations:^{
    _visibleRect.frame    = CGRectMake(HORIZONTAL_INSET + visiblePoint,    rect.origin.y, visibleDimension,    subCellHeight);
    _displayRect.frame    = CGRectMake(HORIZONTAL_INSET + displayPoint,    rect.origin.y, displayDimension,    subCellHeight);
    _preloadRect.frame    = CGRectMake(HORIZONTAL_INSET + preloadPoint,  rect.origin.y, preloadDimension,  subCellHeight);
  } completion:^(BOOL finished) {}];
  
  if (!animate) {
    _visibleRect.alpha = _displayRect.alpha = _preloadRect.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
      _visibleRect.alpha = _displayRect.alpha = _preloadRect.alpha = 1;
    }];
  }
  
  _firstLayoutOfRects = NO;
}

- (void)updateWithVisibleRatio:(CGFloat)visibleRatio
                  displayRatio:(CGFloat)displayRatio
           leadingDisplayRatio:(CGFloat)leadingDisplayRatio
                preloadRatio:(CGFloat)preloadRatio
         leadingpreloadRatio:(CGFloat)leadingpreloadRatio
                     direction:(ASScrollDirection)scrollDirection
{
  _visibleRatio          = visibleRatio;
  _displayRatio          = displayRatio;
  _leadingDisplayRatio   = leadingDisplayRatio;
  _preloadRatio          = preloadRatio;
  _leadingpreloadRatio   = leadingpreloadRatio;
  _scrollDirection       = scrollDirection;
  
  [self setNeedsLayout];
}

- (void)setBarSubviewOrder
{
  if (_preloadRatio == 1.0) {
    [self sendSubviewToBack:_preloadRect.view];
  } else {
    [self sendSubviewToBack:_displayRect.view];
  }
  
  [self bringSubviewToFront:_visibleRect.view];
}

- (void)setBarDebugLabelsWithSize:(CGFloat)size
{
  if (!_debugString) {
    _debugString = [[_rangeController dataSource] nameForRangeControllerDataSource];
  }
  if (_debugString) {
    _debugText.attributedText = [_ASRangeDebugBarView whiteAttributedStringFromString:_debugString withSize:size];
  }
  
  if (ASScrollDirectionContainsVerticalDirection(_scrollDirection)) {
    _leftDebugText.attributedText = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▲" withSize:size];
    _rightDebugText.attributedText = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▼" withSize:size];
  } else if (ASScrollDirectionContainsHorizontalDirection(_scrollDirection)) {
    _leftDebugText.attributedText = [_ASRangeDebugBarView whiteAttributedStringFromString:@"◀︎" withSize:size];
    _rightDebugText.attributedText = [_ASRangeDebugBarView whiteAttributedStringFromString:@"▶︎" withSize:size];
  }
  
  _leftDebugText.hidden = (_scrollDirection != ASScrollDirectionLeft && _scrollDirection != ASScrollDirectionUp);
  _rightDebugText.hidden = (_scrollDirection != ASScrollDirectionRight && _scrollDirection != ASScrollDirectionDown);
}

- (ASTextNode *)createDebugTextNode
{
  ASTextNode *label = [[ASTextNode alloc] init];
  [self addSubnode:label];
  return label;
}

#define RANGE_BAR_CORNER_RADIUS 3
#define RANGE_BAR_BORDER_WIDTH 1
- (ASImageNode *)createRangeNodeWithColor:(UIColor *)color
{
    ASImageNode *rangeBarImageNode = [[ASImageNode alloc] init];
    rangeBarImageNode.image = [UIImage as_resizableRoundedImageWithCornerRadius:RANGE_BAR_CORNER_RADIUS
                                                                    cornerColor:[UIColor clearColor]
                                                                      fillColor:[color colorWithAlphaComponent:0.5]
                                                                    borderColor:[[UIColor blackColor] colorWithAlphaComponent:0.9]
                                                                    borderWidth:RANGE_BAR_BORDER_WIDTH
                                                                 roundedCorners:UIRectCornerAllCorners
                                                                          scale:[[UIScreen mainScreen] scale]];
    [self addSubnode:rangeBarImageNode];
  
    return rangeBarImageNode;
}

+ (NSAttributedString *)whiteAttributedStringFromString:(NSString *)string withSize:(CGFloat)size
{
  NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor whiteColor],
                               NSFontAttributeName            : [UIFont systemFontOfSize:size]};
  return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

@end
