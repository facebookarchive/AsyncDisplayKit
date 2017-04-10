//
//  ASDisplayNode+Beta.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASEventLog.h>

#if YOGA
  #import YOGA_HEADER_PATH
#endif

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN
void ASPerformBlockOnMainThread(void (^block)());
void ASPerformBlockOnBackgroundThread(void (^block)()); // DISPATCH_QUEUE_PRIORITY_DEFAULT
ASDISPLAYNODE_EXTERN_C_END

#if ASEVENTLOG_ENABLE
  #define ASDisplayNodeLogEvent(node, ...) [node.eventLog logEventWithBacktrace:(AS_SAVE_EVENT_BACKTRACES ? [NSThread callStackSymbols] : nil) format:__VA_ARGS__]
#else
  #define ASDisplayNodeLogEvent(node, ...)
#endif

#if ASEVENTLOG_ENABLE
  #define ASDisplayNodeGetEventLog(node) node.eventLog
#else
  #define ASDisplayNodeGetEventLog(node) nil
#endif

/**
 * Bitmask to indicate what performance measurements the cell should record.
 */
typedef NS_OPTIONS(NSUInteger, ASDisplayNodePerformanceMeasurementOptions) {
  ASDisplayNodePerformanceMeasurementOptionLayoutSpec = 1 << 0,
  ASDisplayNodePerformanceMeasurementOptionLayoutComputation = 1 << 1
};

typedef struct {
  CFTimeInterval layoutSpecTotalTime;
  NSInteger layoutSpecNumberOfPasses;
  CFTimeInterval layoutComputationTotalTime;
  NSInteger layoutComputationNumberOfPasses;
} ASDisplayNodePerformanceMeasurements;

@interface ASDisplayNode (Beta)

/**
 * ASTableView and ASCollectionView now throw exceptions on invalid updates
 * like their UIKit counterparts. If YES, these classes will log messages
 * on invalid updates rather than throwing exceptions.
 *
 * Note that even if AsyncDisplayKit's exception is suppressed, the app may still crash
 * as it proceeds with an invalid update.
 *
 * This property defaults to NO. It will be removed in a future release.
 */
+ (BOOL)suppressesInvalidCollectionUpdateExceptions AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Collection update exceptions are thrown if assertions are enabled.");
+ (void)setSuppressesInvalidCollectionUpdateExceptions:(BOOL)suppresses ASDISPLAYNODE_DEPRECATED_MSG("Collection update exceptions are thrown if assertions are enabled.");

/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

/**
 * @abstract allow modification of a context before the node's content is drawn
 *
 * @discussion Set the block to be called after the context has been created and before the node's content is drawn.
 * You can override this to modify the context before the content is drawn. You are responsible for saving and
 * restoring context if necessary. Restoring can be done in contextDidDisplayNodeContent
 * This block can be called from *any* thread and it is unsafe to access any UIKit main thread properties from it.
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;

/**
 * @abstract allow modification of a context after the node's content is drawn
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;

/**
 * @abstract A bitmask representing which actions (layout spec, layout generation) should be measured.
 */
@property (nonatomic, assign) ASDisplayNodePerformanceMeasurementOptions measurementOptions;

/**
 * @abstract A simple struct representing performance measurements collected.
 */
@property (nonatomic, assign, readonly) ASDisplayNodePerformanceMeasurements performanceMeasurements;

#if ASEVENTLOG_ENABLE
/*
 * @abstract The primitive event tracing object. You shouldn't directly use it to log event. Use the ASDisplayNodeLogEvent macro instead.
 */
@property (nonatomic, strong, readonly) ASEventLog *eventLog;
#endif

/**
 * @abstract Currently used by ASNetworkImageNode and ASMultiplexImageNode to allow their placeholders to stay if they are loading an image from the network.
 * Otherwise, a display pass is scheduled and completes, but does not actually draw anything - and ASDisplayNode considers the element finished.
 */
- (BOOL)placeholderShouldPersist AS_WARN_UNUSED_RESULT;

/**
 * @abstract Indicates that the receiver and all subnodes have finished displaying. May be called more than once, for example if the receiver has
 * a network image node. This is called after the first display pass even if network image nodes have not downloaded anything (text would be done,
 * and other nodes that are ready to do their final display). Each render of every progressive jpeg network node would cause this to be called, so
 * this hook could be called up to 1 + (pJPEGcount * pJPEGrenderCount) times. The render count depends on how many times the downloader calls the
 * progressImage block.
 */
- (void)hierarchyDisplayDidFinish;

/**
 * Only ASLayoutRangeModeVisibleOnly or ASLayoutRangeModeLowMemory are recommended.  Default is ASLayoutRangeModeVisibleOnly,
 * because this is the only way to ensure an application will not have blank / flashing views as the user navigates back after
 * a memory warning.  Apps that wish to use the more effective / aggressive ASLayoutRangeModeLowMemory may need to take steps
 * to mitigate this behavior, including: restoring a larger range mode to the next controller before the user navigates there,
 * enabling .neverShowPlaceholders on ASCellNodes so that the navigation operation is blocked on redisplay completing, etc.
 */
+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode;

/**
 * @abstract Whether to draw all descendant nodes' layers/views into this node's layer/view's backing store.
 *
 * @discussion
 * When set to YES, causes all descendant nodes' layers/views to be drawn directly into this node's layer/view's backing
 * store.  Defaults to NO.
 *
 * If a node's descendants are static (never animated or never change attributes after creation) then that node is a
 * good candidate for rasterization.  Rasterizing descendants has two main benefits:
 * 1) Backing stores for descendant layers are not created.  Instead the layers are drawn directly into the rasterized
 * container.  This can save a great deal of memory.
 * 2) Since the entire subtree is drawn into one backing store, compositing and blending are eliminated in that subtree
 * which can help improve animation/scrolling/etc performance.
 *
 * Rasterization does not currently support descendants with transform, sublayerTransform, or alpha. Those properties
 * will be ignored when rasterizing descendants.
 *
 * Note: this has nothing to do with -[CALayer shouldRasterize], which doesn't work with ASDisplayNode's asynchronous
 * rendering model.
 */
@property (nonatomic, assign) BOOL shouldRasterizeDescendants ASDISPLAYNODE_DEPRECATED_MSG("Deprecated in version 2.2");

@end

#pragma mark - Yoga Layout Support

#if YOGA

extern void ASDisplayNodePerformBlockOnEveryYogaChild(ASDisplayNode * _Nullable node, void(^block)(ASDisplayNode *node));

@interface ASDisplayNode (Yoga)

@property (nonatomic, strong) NSArray *yogaChildren;
@property (nonatomic, strong) ASLayout *yogaCalculatedLayout;

- (void)addYogaChild:(ASDisplayNode *)child;
- (void)removeYogaChild:(ASDisplayNode *)child;

// These methods should not normally be called directly.
- (void)invalidateCalculatedYogaLayout;
- (void)calculateLayoutFromYogaRoot:(ASSizeRange)rootConstrainedSize;

@end

@interface ASLayoutElementStyle (Yoga)

@property (nonatomic, assign, readwrite) ASStackLayoutDirection direction;
@property (nonatomic, assign, readwrite) CGFloat spacing;
@property (nonatomic, assign, readwrite) ASStackLayoutJustifyContent justifyContent;
@property (nonatomic, assign, readwrite) ASStackLayoutAlignItems alignItems;
@property (nonatomic, assign, readwrite) YGPositionType positionType;
@property (nonatomic, assign, readwrite) ASEdgeInsets position;
@property (nonatomic, assign, readwrite) ASEdgeInsets margin;
@property (nonatomic, assign, readwrite) ASEdgeInsets padding;
@property (nonatomic, assign, readwrite) ASEdgeInsets border;
@property (nonatomic, assign, readwrite) CGFloat aspectRatio;
@property (nonatomic, assign, readwrite) YGWrap flexWrap;

@end

#endif

NS_ASSUME_NONNULL_END
