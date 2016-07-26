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

#import "AsyncDisplayKit+Debug.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeExtras.h"

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
