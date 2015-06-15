/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASCoreAnimationExtras.h"
#import "_ASAsyncTransaction.h"
#import "ASAssert.h"
#import "ASDisplayNodeInternal.h"

@implementation ASDisplayNode (AsyncDisplay)

/**
 * Support for limiting the number of concurrent displays.
 * Set __ASDisplayLayerMaxConcurrentDisplayCount to change the maximum allowed number of concurrent displays.
 */

#define ASDISPLAYNODE_DELAY_DISPLAY 0

#if ASDISPLAYNODE_DELAY_DISPLAY
static long __ASDisplayLayerMaxConcurrentDisplayCount = 1;
#define ASDN_DELAY_FOR_DISPLAY() usleep( (long)(0.1 * USEC_PER_SEC) )
#else
// Basing this off of CPU core count would make sense, but first some experimentation should be done to understand
// if having more ready-to-run work keeps the CPU clock up (or other interesting scheduler effects).
static long __ASDisplayLayerMaxConcurrentDisplayCount = 8;
#define ASDN_DELAY_FOR_DISPLAY()
#endif

static dispatch_semaphore_t __ASDisplayLayerConcurrentDisplaySemaphore;

/*
 * Call __ASDisplayLayerIncrementConcurrentDisplayCount() upon entry into a display block (either drawRect: or display).
 * This will block if the number of currently executing displays is equal or greater to the limit.
 */
static void __ASDisplayLayerIncrementConcurrentDisplayCount(BOOL displayIsAsync, BOOL isRasterizing)
{
  // Displays while rasterizing are not counted as concurrent displays, because they draw in serial when their rasterizing container displays.
  if (isRasterizing) {
    return;
  }

  static dispatch_once_t onceToken;
  if (displayIsAsync) {
    dispatch_once(&onceToken, ^{
      __ASDisplayLayerConcurrentDisplaySemaphore = dispatch_semaphore_create(__ASDisplayLayerMaxConcurrentDisplayCount);
    });

    dispatch_semaphore_wait(__ASDisplayLayerConcurrentDisplaySemaphore, DISPATCH_TIME_FOREVER);
  }
}

/*
 * Call __ASDisplayLayerDecrementConcurrentDisplayCount() upon exit from a display block, matching calls to __ASDisplayLayerIncrementConcurrentDisplayCount().
 */
static void __ASDisplayLayerDecrementConcurrentDisplayCount(BOOL displayIsAsync, BOOL isRasterizing)
{
  // Displays while rasterizing are not counted as concurrent displays, becuase they draw in serial when their rasterizing container displays.
  if (isRasterizing) {
    return;
  }

  if (displayIsAsync) {
    dispatch_semaphore_signal(__ASDisplayLayerConcurrentDisplaySemaphore);
  }
}

- (NSObject *)drawParameters
{
  if (_flags.implementsDrawParameters) {
    return [self drawParametersForAsyncLayer:self.asyncLayer];
  }

  return nil;
}

- (void)_recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock displayBlocks:(NSMutableArray *)displayBlocks
{
  // Skip subtrees that are hidden or zero alpha.
  if (self.isHidden || self.alpha <= 0.0) {
    return;
  }

  // Capture these outside the display block so they are retained.
  UIColor *backgroundColor = self.backgroundColor;
  CGRect bounds = self.bounds;

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

  // We'll display something if there is a display block and/or a background color.
  BOOL shouldDisplay = displayBlock || backgroundColor;

  // If we should display, then push a transform, draw the background color, and draw the contents.
  // The transform is popped in a block added after the recursion into subnodes.
  if (shouldDisplay) {
    dispatch_block_t pushAndDisplayBlock = ^{
      // Push transform relative to parent.
      CGContextRef context = UIGraphicsGetCurrentContext();
      CGContextSaveGState(context);

      CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);

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
          [image drawInRect:bounds];
        }
      }
    };
    [displayBlocks addObject:[pushAndDisplayBlock copy]];
  }

  // Recursively capture displayBlocks for all descendants.
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];
  }

  // If we pushed a transform, pop it by adding a display block that does nothing other than that.
  if (shouldDisplay) {
    dispatch_block_t popBlock = ^{
      CGContextRef context = UIGraphicsGetCurrentContext();
      CGContextRestoreGState(context);
    };
    [displayBlocks addObject:[popBlock copy]];
  }
}

- (asyncdisplaykit_async_transaction_operation_block_t)_displayBlockWithAsynchronous:(BOOL)asynchronous isCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock rasterizing:(BOOL)rasterizing
{
  id nodeClass = [self class];

  asyncdisplaykit_async_transaction_operation_block_t displayBlock = nil;

  ASDisplayNodeAssert(rasterizing || ![self __rasterizedContainerNode], @"Rasterized descendants should never display unless being drawn into the rasterized container.");

  if (!rasterizing && self.shouldRasterizeDescendants) {
    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) {
      return nil;
    }

    // Collect displayBlocks for all descendants.
    NSMutableArray *displayBlocks = [NSMutableArray array];
    [self _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];

    CGFloat contentsScaleForDisplay = self.contentsScaleForDisplay;
    BOOL opaque = self.opaque && CGColorGetAlpha(self.backgroundColor.CGColor) == 1.0f;

    ASDisplayNodeAssert(self.contentsScaleForDisplay != 0.0, @"Invalid contents scale");

    displayBlock = ^id{
      __ASDisplayLayerIncrementConcurrentDisplayCount(asynchronous, rasterizing);
      if (isCancelledBlock()) {
        __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
        return nil;
      }

      ASDN_DELAY_FOR_DISPLAY();
      UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, contentsScaleForDisplay);

      for (dispatch_block_t block in displayBlocks) {
        if (isCancelledBlock()) {
          UIGraphicsEndImageContext();
          __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
          return nil;
        }
        block();
      }

      UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();

      __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);

      return image;
    };
  } else if (_flags.implementsImageDisplay) {
    // Capture drawParameters from delegate on main thread
    id drawParameters = [self drawParameters];

    displayBlock = ^id{
      __ASDisplayLayerIncrementConcurrentDisplayCount(asynchronous, rasterizing);
      if (isCancelledBlock()) {
        __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
        return nil;
      }

      ASDN_DELAY_FOR_DISPLAY();

      UIImage *result = [nodeClass displayWithParameters:drawParameters isCancelled:isCancelledBlock];
      __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
      return result;
    };

  } else if (_flags.implementsDrawRect) {

    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) {
      return nil;
    }

    // Capture drawParameters from delegate on main thread
    id drawParameters = [self drawParameters];
    CGFloat contentsScaleForDisplay = self.contentsScaleForDisplay;
    BOOL opaque = self.opaque;

    displayBlock = ^id{
      __ASDisplayLayerIncrementConcurrentDisplayCount(asynchronous, rasterizing);
      if (isCancelledBlock()) {
        __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
        return nil;
      }

      ASDN_DELAY_FOR_DISPLAY();

      if (!rasterizing) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, contentsScaleForDisplay);
      }

      [nodeClass drawRect:bounds withParameters:drawParameters isCancelled:isCancelledBlock isRasterizing:rasterizing];

      if (isCancelledBlock()) {
        if (!rasterizing) {
          UIGraphicsEndImageContext();
        }
        __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);
        return nil;
      }

      UIImage *image = nil;
      if (!rasterizing) {
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
      }

      __ASDisplayLayerDecrementConcurrentDisplayCount(asynchronous, rasterizing);

      return image;
    };

  }

  return [displayBlock copy];
}

- (void)displayAsyncLayer:(_ASDisplayLayer *)asyncLayer asynchronously:(BOOL)asynchronously
{
  ASDisplayNodeAssertMainThread();

  ASDN::MutexLocker l(_propertyLock);

  if ([self __rasterizedContainerNode]) {
    return;
  }

  // for async display, capture the current displaySentinel value to bail early when the job is executed if another is
  // enqueued
  // for sync display, just use nil for the displaySentinel and go
  //
  // REVIEW: what about the degenerate case where we are calling setNeedsDisplay faster than the jobs are dequeuing
  // from the displayQueue?  do we want to put in some kind of timer to not cancel early fails from displaySentinel
  // changes?
  ASSentinel *displaySentinel = (asynchronously ? _displaySentinel : nil);
  int64_t displaySentinelValue = [displaySentinel increment];

  asdisplaynode_iscancelled_block_t isCancelledBlock = ^{
    return BOOL(displaySentinelValue != displaySentinel.value);
  };

  // If we're participating in an ancestor's asyncTransaction, find it here
  ASDisplayNodeAssert(_layer, @"Expect _layer to be not nil");
  CALayer *containerLayer = _layer.asyncdisplaykit_parentTransactionContainer ?: _layer;
  _ASAsyncTransaction *transaction = containerLayer.asyncdisplaykit_asyncTransaction;

  // Set up displayBlock to call either display or draw on the delegate and return a UIImage contents
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = [self _displayBlockWithAsynchronous:asynchronously isCancelledBlock:isCancelledBlock rasterizing:NO];
  if (!displayBlock) {
    return;
  }

  // This block is called back on the main thread after rendering at the completion of the current async transaction, or immediately if !asynchronously
  asyncdisplaykit_async_transaction_operation_completion_block_t completionBlock = ^(id<NSObject> value, BOOL canceled){
    ASDisplayNodeCAssertMainThread();
    if (!canceled && !isCancelledBlock()) {
      UIImage *image = (UIImage *)value;
      BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
      if (stretchable) {
        ASDisplayNodeSetupLayerContentsWithResizableImage(_layer, image);
      } else {
        _layer.contentsScale = self.contentsScale;
        _layer.contents = (id)image.CGImage;
      }
      [self didDisplayAsyncLayer:self.asyncLayer];
    }
  };

  if (displayBlock != NULL) {
    // Call willDisplay immediately in either case
    [self willDisplayAsyncLayer:self.asyncLayer];

    if (asynchronously) {
      [transaction addOperationWithBlock:displayBlock queue:[_ASDisplayLayer displayQueue] completion:completionBlock];
    } else {
      UIImage *contents = (UIImage *)displayBlock();
      completionBlock(contents, NO);
    }
  }
}

- (void)cancelDisplayAsyncLayer:(_ASDisplayLayer *)asyncLayer
{
  [_displaySentinel increment];
}

@end
