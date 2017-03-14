//
//  ASDisplayNode+AsyncDisplay.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@interface ASDisplayNode () <_ASDisplayLayerDelegate>
@end

@implementation ASDisplayNode (AsyncDisplay)

#if ASDISPLAYNODE_DELAY_DISPLAY
  #define ASDN_DELAY_FOR_DISPLAY() usleep( (long)(0.1 * USEC_PER_SEC) )
#else
  #define ASDN_DELAY_FOR_DISPLAY()
#endif

#define CHECK_CANCELLED_AND_RETURN_NIL(expr)                      if (isCancelledBlock()) { \
                                                                    expr; \
                                                                    return nil; \
                                                                  } \

- (NSObject *)drawParameters
{
  __instanceLock__.lock();
  BOOL implementsDrawParameters = _flags.implementsDrawParameters;
  __instanceLock__.unlock();

  if (implementsDrawParameters) {
    return [self drawParametersForAsyncLayer:self.asyncLayer];
  } else {
    return nil;
  }
}

- (void)_recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock displayBlocks:(NSMutableArray *)displayBlocks
{
  // Skip subtrees that are hidden or zero alpha.
  if (self.isHidden || self.alpha <= 0.0) {
    return;
  }
  
  __instanceLock__.lock();
  BOOL rasterizingFromAscendent = (_hierarchyState & ASHierarchyStateRasterized);
  __instanceLock__.unlock();

  // if super node is rasterizing descendants, subnodes will not have had layout calls because they don't have layers
  if (rasterizingFromAscendent) {
    [self __layout];
  }

  // Capture these outside the display block so they are retained.
  UIColor *backgroundColor = self.backgroundColor;
  CGRect bounds = self.bounds;
  CGFloat cornerRadius = self.cornerRadius;
  BOOL clipsToBounds = self.clipsToBounds;

  CGRect frame;
  
  // If this is the root container node, use a frame with a zero origin to draw into. If not, calculate the correct frame using the node's position, transform and anchorPoint.
  if (self.shouldRasterizeDescendants) {
    frame = CGRectMake(0.0f, 0.0f, bounds.size.width, bounds.size.height);
  } else {
    CGPoint position = self.position;
    CGPoint anchorPoint = self.anchorPoint;
    
    // Pretty hacky since full 3D transforms aren't actually supported, but attempt to compute the transformed frame of this node so that we can composite it into approximately the right spot.
    CGAffineTransform transform = CATransform3DGetAffineTransform(self.transform);
    CGSize scaledBoundsSize = CGSizeApplyAffineTransform(bounds.size, transform);
    CGPoint origin = CGPointMake(position.x - scaledBoundsSize.width * anchorPoint.x,
                                 position.y - scaledBoundsSize.height * anchorPoint.y);
    frame = CGRectMake(origin.x, origin.y, bounds.size.width, bounds.size.height);
  }

  // Get the display block for this node.
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = [self _displayBlockWithAsynchronous:NO isCancelledBlock:isCancelledBlock rasterizing:YES];

  // We'll display something if there is a display block, clipping, translation and/or a background color.
  BOOL shouldDisplay = displayBlock || backgroundColor || CGPointEqualToPoint(CGPointZero, frame.origin) == NO || clipsToBounds;

  // If we should display, then push a transform, draw the background color, and draw the contents.
  // The transform is popped in a block added after the recursion into subnodes.
  if (shouldDisplay) {
    dispatch_block_t pushAndDisplayBlock = ^{
      // Push transform relative to parent.
      CGContextRef context = UIGraphicsGetCurrentContext();
      CGContextSaveGState(context);

      CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);

      //support cornerRadius
      if (rasterizingFromAscendent && clipsToBounds) {
        if (cornerRadius) {
          [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:cornerRadius] addClip];
        } else {
          CGContextClipToRect(context, bounds);
        }
      }

      // Fill background if any.
      CGColorRef backgroundCGColor = backgroundColor.CGColor;
      if (backgroundColor && CGColorGetAlpha(backgroundCGColor) > 0.0) {
        CGContextSetFillColorWithColor(context, backgroundCGColor);
        CGContextFillRect(context, bounds);
      }

      // If there is a display block, call it to get the image, then copy the image into the current context (which is the rasterized container's backing store).
      if (displayBlock) {
        UIImage *image = (UIImage *)displayBlock();
        if (image) {
          BOOL opaque = ASImageAlphaInfoIsOpaque(CGImageGetAlphaInfo(image.CGImage));
          CGBlendMode blendMode = opaque ? kCGBlendModeCopy : kCGBlendModeNormal;
          [image drawInRect:bounds blendMode:blendMode alpha:1];
        }
      }
    };
    [displayBlocks addObject:pushAndDisplayBlock];
  }

  // Recursively capture displayBlocks for all descendants.
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];
  }

  // If we pushed a transform, pop it by adding a display block that does nothing other than that.
  if (shouldDisplay) {
    // Since this block is pure, we can store it statically.
    static dispatch_block_t popBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      popBlock = ^{
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextRestoreGState(context);
      };
    });
    [displayBlocks addObject:popBlock];
  }
}

- (asyncdisplaykit_async_transaction_operation_block_t)_displayBlockWithAsynchronous:(BOOL)asynchronous
                                                                    isCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock
                                                                         rasterizing:(BOOL)rasterizing
{
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = nil;
  ASDisplayNodeFlags flags;
  
  __instanceLock__.lock();

  flags = _flags;
  
  // We always create a graphics context, unless a -display method is used, OR if we are a subnode drawing into a rasterized parent.
  BOOL shouldCreateGraphicsContext = (flags.implementsInstanceImageDisplay == NO && flags.implementsImageDisplay == NO && rasterizing == NO);
  BOOL shouldBeginRasterizing = (rasterizing == NO && flags.shouldRasterizeDescendants);
  BOOL usesInstanceMethodDisplay = (flags.implementsInstanceDrawRect || flags.implementsInstanceImageDisplay);
  BOOL usesImageDisplay = (flags.implementsImageDisplay || flags.implementsInstanceImageDisplay);
  BOOL usesDrawRect = (flags.implementsDrawRect || flags.implementsInstanceDrawRect);
  
  if (usesImageDisplay == NO && usesDrawRect == NO && shouldBeginRasterizing == NO) {
    // Early exit before requesting more expensive properties like bounds and opaque from the layer.
    __instanceLock__.unlock();
    return nil;
  }
  
  BOOL opaque = self.opaque;
  CGRect bounds = self.bounds;
  CGFloat contentsScaleForDisplay = _contentsScaleForDisplay;
    
  __instanceLock__.unlock();

  // Capture drawParameters from delegate on main thread, if this node is displaying itself rather than recursively rasterizing.
  id drawParameters = (shouldBeginRasterizing == NO ? [self drawParameters] : nil);
  
  // Only the -display methods should be called if we can't size the graphics buffer to use.
  if (CGRectIsEmpty(bounds) && (shouldBeginRasterizing || shouldCreateGraphicsContext)) {
    return nil;
  }
  
  ASDisplayNodeAssert(contentsScaleForDisplay != 0.0, @"Invalid contents scale");
  ASDisplayNodeAssert(usesInstanceMethodDisplay == NO || (flags.implementsDrawRect == NO && flags.implementsImageDisplay == NO),
                      @"Node %@ should not implement both class and instance method display or draw", self);
  ASDisplayNodeAssert(rasterizing || !(_hierarchyState & ASHierarchyStateRasterized),
                      @"Rasterized descendants should never display unless being drawn into the rasterized container.");

  if (shouldBeginRasterizing) {
    // Collect displayBlocks for all descendants.
    NSMutableArray *displayBlocks = [NSMutableArray array];
    [self _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];
    CHECK_CANCELLED_AND_RETURN_NIL();
    
    // If [UIColor clearColor] or another semitransparent background color is used, include alpha channel when rasterizing.
    // Unlike CALayer drawing, we include the backgroundColor as a base during rasterization.
    opaque = opaque && CGColorGetAlpha(self.backgroundColor.CGColor) == 1.0f;

    displayBlock = ^id{
      CHECK_CANCELLED_AND_RETURN_NIL();
      
      UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, contentsScaleForDisplay);

      for (dispatch_block_t block in displayBlocks) {
        CHECK_CANCELLED_AND_RETURN_NIL(UIGraphicsEndImageContext());
        block();
      }
      
      UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();

      ASDN_DELAY_FOR_DISPLAY();
      return image;
    };
  } else {
    displayBlock = ^id{
      CHECK_CANCELLED_AND_RETURN_NIL();

      if (shouldCreateGraphicsContext) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, contentsScaleForDisplay);
        CHECK_CANCELLED_AND_RETURN_NIL( UIGraphicsEndImageContext(); );
      }

      CGContextRef currentContext = UIGraphicsGetCurrentContext();
      UIImage *image = nil;
        
      ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext = nil;
      ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext = nil;
      if (currentContext) {
        __instanceLock__.lock();
        willDisplayNodeContentWithRenderingContext = _willDisplayNodeContentWithRenderingContext;
        didDisplayNodeContentWithRenderingContext = _didDisplayNodeContentWithRenderingContext;
        __instanceLock__.unlock();
      }
        

      // For -display methods, we don't have a context, and thus will not call the _willDisplayNodeContentWithRenderingContext or
      // _didDisplayNodeContentWithRenderingContext blocks. It's up to the implementation of -display... to do what it needs.
      if (willDisplayNodeContentWithRenderingContext != nil) {
        willDisplayNodeContentWithRenderingContext(currentContext);
      }
      
      // Decide if we use a class or instance method to draw or display.
      id object = usesInstanceMethodDisplay ? self : [self class];
      
      if (usesImageDisplay) {                                   // If we are using a display method, we'll get an image back directly.
        image = [object displayWithParameters:drawParameters
                                  isCancelled:isCancelledBlock];
      } else if (usesDrawRect) {                                // If we're using a draw method, this will operate on the currentContext.
        [object drawRect:bounds withParameters:drawParameters
             isCancelled:isCancelledBlock isRasterizing:rasterizing];
      }
      
      if (didDisplayNodeContentWithRenderingContext != nil) {
        didDisplayNodeContentWithRenderingContext(currentContext);
      }
      
      if (shouldCreateGraphicsContext) {
        CHECK_CANCELLED_AND_RETURN_NIL( UIGraphicsEndImageContext(); );
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
      }

      ASDN_DELAY_FOR_DISPLAY();
      return image;
    };
  }

  return displayBlock;
}

- (void)displayAsyncLayer:(_ASDisplayLayer *)asyncLayer asynchronously:(BOOL)asynchronously
{
  ASDisplayNodeAssertMainThread();
  
  __instanceLock__.lock();
  
  if (_hierarchyState & ASHierarchyStateRasterized) {
    __instanceLock__.unlock();
    return;
  }
  
  CALayer *layer = _layer;
  
  __instanceLock__.unlock();

  // for async display, capture the current displaySentinel value to bail early when the job is executed if another is
  // enqueued
  // for sync display, do not support cancellation
  
  // FIXME: what about the degenerate case where we are calling setNeedsDisplay faster than the jobs are dequeuing
  // from the displayQueue?  Need to not cancel early fails from displaySentinel changes.
  asdisplaynode_iscancelled_block_t isCancelledBlock = nil;
  if (asynchronously) {
    uint displaySentinelValue = ++_displaySentinel;
    __weak ASDisplayNode *weakSelf = self;
    isCancelledBlock = ^BOOL{
      __strong ASDisplayNode *self = weakSelf;
      return self == nil || (displaySentinelValue != self->_displaySentinel.load());
    };
  } else {
    isCancelledBlock = ^BOOL{
      return NO;
    };
  }

  // Set up displayBlock to call either display or draw on the delegate and return a UIImage contents
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = [self _displayBlockWithAsynchronous:asynchronously isCancelledBlock:isCancelledBlock rasterizing:NO];
  
  if (!displayBlock) {
    return;
  }
  
  ASDisplayNodeAssert(_layer, @"Expect _layer to be not nil");

  // This block is called back on the main thread after rendering at the completion of the current async transaction, or immediately if !asynchronously
  asyncdisplaykit_async_transaction_operation_completion_block_t completionBlock = ^(id<NSObject> value, BOOL canceled){
    ASDisplayNodeCAssertMainThread();
    if (!canceled && !isCancelledBlock()) {
      UIImage *image = (UIImage *)value;
      BOOL stretchable = (NO == UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero));
      if (stretchable) {
        ASDisplayNodeSetupLayerContentsWithResizableImage(layer, image);
      } else {
        layer.contentsScale = self.contentsScale;
        layer.contents = (id)image.CGImage;
      }
      [self didDisplayAsyncLayer:self.asyncLayer];
    }
  };

  // Call willDisplay immediately in either case
  [self willDisplayAsyncLayer:self.asyncLayer asynchronously:asynchronously];

  if (asynchronously) {
    // Async rendering operations are contained by a transaction, which allows them to proceed and concurrently
    // while synchronizing the final application of the results to the layer's contents property (completionBlock).
    
    // First, look to see if we are expected to join a parent's transaction container.
    CALayer *containerLayer = layer.asyncdisplaykit_parentTransactionContainer ? : layer;
    
    // In the case that a transaction does not yet exist (such as for an individual node outside of a container),
    // this call will allocate the transaction and add it to _ASAsyncTransactionGroup.
    // It will automatically commit the transaction at the end of the runloop.
    _ASAsyncTransaction *transaction = containerLayer.asyncdisplaykit_asyncTransaction;
    
    // Adding this displayBlock operation to the transaction will start it IMMEDIATELY.
    // The only function of the transaction commit is to gate the calling of the completionBlock.
    [transaction addOperationWithBlock:displayBlock priority:self.drawingPriority queue:[_ASDisplayLayer displayQueue] completion:completionBlock];
  } else {
    UIImage *contents = (UIImage *)displayBlock();
    completionBlock(contents, NO);
  }
}

- (void)cancelDisplayAsyncLayer:(_ASDisplayLayer *)asyncLayer
{
  _displaySentinel.fetch_add(1);
}

- (ASDisplayNodeContextModifier)willDisplayNodeContentWithRenderingContext
{
  ASDN::MutexLocker l(__instanceLock__);
  return _willDisplayNodeContentWithRenderingContext;
}

- (ASDisplayNodeContextModifier)didDisplayNodeContentWithRenderingContext
{
  ASDN::MutexLocker l(__instanceLock__);
  return _didDisplayNodeContentWithRenderingContext;
}

- (void)setWillDisplayNodeContentWithRenderingContext:(ASDisplayNodeContextModifier)contextModifier
{
  ASDN::MutexLocker l(__instanceLock__);
  _willDisplayNodeContentWithRenderingContext = contextModifier;
}

- (void)setDidDisplayNodeContentWithRenderingContext:(ASDisplayNodeContextModifier)contextModifier;
{
  ASDN::MutexLocker l(__instanceLock__);
  _didDisplayNodeContentWithRenderingContext = contextModifier;
}

@end
