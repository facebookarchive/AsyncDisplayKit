/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <QuartzCore/QuartzCore.h>

#import <XCTest/XCTest.h>

#import "_ASDisplayLayer.h"
#import "_ASDisplayView.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeTestsHelper.h"
#import "UIView+ASConvenience.h"

// Conveniences for making nodes named a certain way

#define DeclareNodeNamed(n) ASDisplayNode *n = [[ASDisplayNode alloc] init]; n.name = @#n
#define DeclareViewNamed(v) UIView *v = [[UIView alloc] init]; v.layer.asyncdisplaykit_name = @#v
#define DeclareLayerNamed(l) CALayer *l = [[CALayer alloc] init]; l.asyncdisplaykit_name = @#l

static NSString *orderStringFromSublayers(CALayer *l) {
  return [[[l.sublayers valueForKey:@"asyncdisplaykit_name"] allObjects] componentsJoinedByString:@","];
}

static NSString *orderStringFromSubviews(UIView *v) {
  return [[[v.subviews valueForKeyPath:@"layer.asyncdisplaykit_name"] allObjects] componentsJoinedByString:@","];
}

static NSString *orderStringFromSubnodes(ASDisplayNode *n) {
  return [[[n.subnodes valueForKey:@"name"] allObjects] componentsJoinedByString:@","];
}

// Asserts subnode, subview, sublayer order match what you provide here
#define XCTAssertNodeSubnodeSubviewSublayerOrder(n, loaded, isLayerBacked, order, description) \
XCTAssertEqualObjects(orderStringFromSubnodes(n), order, @"Incorrect node order for "  description );\
if (loaded) {\
  if (!isLayerBacked) {\
    XCTAssertEqualObjects(orderStringFromSubviews(n.view), order, @"Incorrect subviews for " description);\
  }\
  XCTAssertEqualObjects(orderStringFromSublayers(n.layer), order, @"Incorrect sublayers for " description);\
}

#define XCTAssertNodesHaveParent(parent, nodes ...) \
for (ASDisplayNode *n in @[ nodes ]) {\
  XCTAssertEqualObjects(parent, n.supernode, @"%@ has the wrong parent", n.name);\
}

#define XCTAssertNodesLoaded(nodes ...) \
for (ASDisplayNode *n in @[ nodes ]) {\
  XCTAssertTrue(n.nodeLoaded, @"%@ should be loaded", n.name);\
}

#define XCTAssertNodesNotLoaded(nodes ...) \
for (ASDisplayNode *n in @[ nodes ]) {\
  XCTAssertFalse(n.nodeLoaded, @"%@ should not be loaded", n.name);\
}


@interface ASDisplayNode (HackForTests)
+ (dispatch_queue_t)asyncSizingQueue;
- (id)initWithViewClass:(Class)viewClass;
- (id)initWithLayerClass:(Class)layerClass;
@end

@interface ASTestDisplayNode : ASDisplayNode
@property (atomic, copy) void (^willDeallocBlock)(ASTestDisplayNode *node);
@property (atomic, copy) CGSize(^calculateSizeBlock)(ASTestDisplayNode *node, CGSize size);
@end

@implementation ASTestDisplayNode

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  return _calculateSizeBlock ? _calculateSizeBlock(self, constrainedSize) : CGSizeZero;
}

- (void)dealloc
{
  if (_willDeallocBlock) {
    _willDeallocBlock(self);
  }
  [super dealloc];
}

@end

@interface UIDisplayNodeTestView : UIView
@end

@implementation UIDisplayNodeTestView
@end

@interface ASDisplayNodeTests : XCTestCase
@end

@implementation ASDisplayNodeTests
{
  dispatch_queue_t queue;
}

- (void)setUp
{
  [super setUp];
  queue = dispatch_queue_create("com.facebook.AsyncDisplayKit.ASDisplayNodeTestsQueue", NULL);
}

- (void)tearDown
{
  dispatch_release(queue);
  [super tearDown];
}

- (void)testViewCreatedOffThreadCanBeRealizedOnThread
{
  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] init];
  }];

  UIView *view = node.view;
  XCTAssertNotNil(view, @"Getting node's view on-thread should succeed.");
}

- (void)testNodeCreatedOffThreadWithExistingView
{
  UIView *view = [[UIDisplayNodeTestView alloc] init];

  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      return view;
    }];
  }];

  XCTAssertFalse(node.layerBacked, @"Can't be layer backed");
  XCTAssertTrue(node.synchronous, @"Node with plain view should be synchronous");
  XCTAssertFalse(node.nodeLoaded, @"Shouldn't have a view yet");
  XCTAssertEqual(view, node.view, @"Getting node's view on-thread should succeed.");
}

- (void)testNodeCreatedOffThreadWithLazyView
{
  __block UIView *view = nil;
  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      XCTAssertTrue([NSThread isMainThread], @"View block must run on the main queue");
      view = [[UIDisplayNodeTestView alloc] init];
      return view;
    }];
  }];

  XCTAssertNil(view, @"View block should not be invoked yet");
  [node view];
  XCTAssertNotNil(view, @"View block should have been invoked");
  XCTAssertEqual(view, node.view, @"Getting node's view on-thread should succeed.");
  XCTAssertTrue(node.synchronous, @"Node with plain view should be synchronous");
}

- (void)testNodeCreatedWithLazyAsyncView
{
  ASDisplayNode *node = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
    XCTAssertTrue([NSThread isMainThread], @"View block must run on the main queue");
    return [[_ASDisplayView alloc] init];
  }];

  XCTAssertThrows([node view], @"Externally provided views should be synchronous");
  XCTAssertTrue(node.synchronous, @"Node with externally provided view should be synchronous");
}

- (void)checkValuesMatchDefaults:(ASDisplayNode *)node isLayerBacked:(BOOL)isLayerBacked
{
  NSString *targetName = isLayerBacked ? @"layer" : @"view";
  NSString *hasLoadedView = node.nodeLoaded ? @"with view" : [NSString stringWithFormat:@"after loading %@", targetName];

  id rgbBlackCGColorIdPtr = (id)[UIColor colorWithRed:0 green:0 blue:0 alpha:1].CGColor;

  XCTAssertEqual((id)nil, node.contents, @"default contents broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.clipsToBounds, @"default clipsToBounds broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.opaque, @"default opaque broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.needsDisplayOnBoundsChange, @"default needsDisplayOnBoundsChange broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.allowsEdgeAntialiasing, @"default allowsEdgeAntialiasing broken %@", hasLoadedView);
  XCTAssertEqual((unsigned int)(kCALayerLeftEdge | kCALayerRightEdge | kCALayerBottomEdge | kCALayerTopEdge), node.edgeAntialiasingMask, @"default edgeAntialisingMask broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.hidden, @"default hidden broken %@", hasLoadedView);
  XCTAssertEqual(1.0f, node.alpha, @"default alpha broken %@", hasLoadedView);
  XCTAssertTrue(CGRectEqualToRect(CGRectZero, node.bounds), @"default bounds broken %@", hasLoadedView);
  XCTAssertTrue(CGRectEqualToRect(CGRectZero, node.frame), @"default frame broken %@", hasLoadedView);
  XCTAssertTrue(CGPointEqualToPoint(CGPointZero, node.position), @"default position broken %@", hasLoadedView);
  XCTAssertEqual((CGFloat)0.0, node.zPosition, @"default zPosition broken %@", hasLoadedView);
  XCTAssertEqual(1.0f, node.contentsScale, @"default contentsScale broken %@", hasLoadedView);
  XCTAssertEqual([UIScreen mainScreen].scale, node.contentsScaleForDisplay, @"default contentsScaleForDisplay broken %@", hasLoadedView);
  XCTAssertTrue(CATransform3DEqualToTransform(CATransform3DIdentity, node.transform), @"default transform broken %@", hasLoadedView);
  XCTAssertTrue(CATransform3DEqualToTransform(CATransform3DIdentity, node.subnodeTransform), @"default subnodeTransform broken %@", hasLoadedView);
  XCTAssertEqual((id)nil, node.backgroundColor, @"default backgroundColor broken %@", hasLoadedView);
  XCTAssertEqual(UIViewContentModeScaleToFill, node.contentMode, @"default contentMode broken %@", hasLoadedView);
  XCTAssertEqualObjects(rgbBlackCGColorIdPtr, (id)node.shadowColor, @"default shadowColor broken %@", hasLoadedView);
  XCTAssertEqual(0.0f, node.shadowOpacity, @"default shadowOpacity broken %@", hasLoadedView);
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(0, -3), node.shadowOffset), @"default shadowOffset broken %@", hasLoadedView);
  XCTAssertEqual(3.f, node.shadowRadius, @"default shadowRadius broken %@", hasLoadedView);
  XCTAssertEqual(0.0f, node.borderWidth, @"default borderWidth broken %@", hasLoadedView);
  XCTAssertEqualObjects(rgbBlackCGColorIdPtr, (id)node.borderColor, @"default borderColor broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.displaySuspended, @"default displaySuspended broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.displaysAsynchronously, @"default displaysAsynchronously broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.asyncdisplaykit_asyncTransactionContainer, @"default asyncdisplaykit_asyncTransactionContainer broken %@", hasLoadedView);
  XCTAssertEqualObjects(nil, node.name, @"default name broken %@", hasLoadedView);

  if (!isLayerBacked) {
    XCTAssertEqual(YES, node.userInteractionEnabled, @"default userInteractionEnabled broken %@", hasLoadedView);
    XCTAssertEqual(NO, node.exclusiveTouch, @"default exclusiveTouch broken %@", hasLoadedView);
    XCTAssertEqual(YES, node.autoresizesSubviews, @"default autoresizesSubviews broken %@", hasLoadedView);
    XCTAssertEqual(UIViewAutoresizingNone, node.autoresizingMask, @"default autoresizingMask broken %@", hasLoadedView);
  } else {
    XCTAssertEqual(NO, node.userInteractionEnabled, @"layer-backed nodes do not support userInteractionEnabled %@", hasLoadedView);
    XCTAssertEqual(NO, node.exclusiveTouch, @"layer-backed nodes do not support exclusiveTouch %@", hasLoadedView);
  }

  if (!isLayerBacked) {
    XCTAssertEqual(NO, node.isAccessibilityElement, @"default isAccessibilityElement is broken %@", hasLoadedView);
    XCTAssertEqual((id)nil, node.accessibilityLabel, @"default accessibilityLabel is broken %@", hasLoadedView);
    XCTAssertEqual((id)nil, node.accessibilityHint, @"default accessibilityHint is broken %@", hasLoadedView);
    XCTAssertEqual((id)nil, node.accessibilityValue, @"default accessibilityValue is broken %@", hasLoadedView);
    XCTAssertEqual(UIAccessibilityTraitNone, node.accessibilityTraits, @"default accessibilityTraits is broken %@", hasLoadedView);
    XCTAssertTrue(CGRectEqualToRect(CGRectZero, node.accessibilityFrame), @"default accessibilityFrame is broken %@", hasLoadedView);
    XCTAssertEqual((id)nil, node.accessibilityLanguage, @"default accessibilityLanguage is broken %@", hasLoadedView);
    XCTAssertEqual(NO, node.accessibilityElementsHidden, @"default accessibilityElementsHidden is broken %@", hasLoadedView);
    XCTAssertEqual(NO, node.accessibilityViewIsModal, @"default accessibilityViewIsModal is broken %@", hasLoadedView);
    XCTAssertEqual(NO, node.shouldGroupAccessibilityChildren, @"default shouldGroupAccessibilityChildren is broken %@", hasLoadedView);
  }
}

- (void)checkDefaultPropertyValuesWithLayerBacking:(BOOL)isLayerBacked
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];

  XCTAssertEqual(NO, node.isLayerBacked, @"default isLayerBacked broken without view");
  node.layerBacked = isLayerBacked;
  XCTAssertEqual(isLayerBacked, node.isLayerBacked, @"setIsLayerBacked: broken");

  // Assert that the values can be fetched from the node before the view is realized.
  [self checkValuesMatchDefaults:node isLayerBacked:isLayerBacked];

  [node layer]; // Force either view or layer loading
  XCTAssertTrue(node.nodeLoaded, @"Didn't load view");

  // Assert that the values can be fetched from the node after the view is realized.
  [self checkValuesMatchDefaults:node isLayerBacked:isLayerBacked];
}

- (void)testDefaultPropertyValuesLayer
{
  [self checkDefaultPropertyValuesWithLayerBacking:YES];
}

- (void)testDefaultPropertyValuesView
{
  [self checkDefaultPropertyValuesWithLayerBacking:NO];
}

- (UIImage *)bogusImage
{
  static UIImage *bogusImage;
  if (!bogusImage) {
    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    bogusImage = [UIGraphicsGetImageFromCurrentImageContext() retain];
    UIGraphicsEndImageContext();
  }
  return bogusImage;
}

- (void)checkValuesMatchSetValues:(ASDisplayNode *)node isLayerBacked:(BOOL)isLayerBacked
{
  NSString *targetName = isLayerBacked ? @"layer" : @"view";
  NSString *hasLoadedView = node.nodeLoaded ? @"with view" : [NSString stringWithFormat:@"after loading %@", targetName];

  XCTAssertEqual(isLayerBacked, node.isLayerBacked, @"isLayerBacked broken %@", hasLoadedView);
  XCTAssertEqualObjects((id)[self bogusImage].CGImage, (id)node.contents, @"contents broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.clipsToBounds, @"clipsToBounds broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.opaque, @"opaque broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.needsDisplayOnBoundsChange, @"needsDisplayOnBoundsChange broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.allowsEdgeAntialiasing, @"allowsEdgeAntialiasing broken %@", hasLoadedView);
  XCTAssertTrue((unsigned int)(kCALayerLeftEdge | kCALayerTopEdge) == node.edgeAntialiasingMask, @"edgeAntialiasingMask broken: %@", hasLoadedView);
  XCTAssertEqual(YES, node.hidden, @"hidden broken %@", hasLoadedView);
  XCTAssertEqual(.5f, node.alpha, @"alpha broken %@", hasLoadedView);
  XCTAssertTrue(CGRectEqualToRect(CGRectMake(10, 15, 42, 115.2), node.bounds), @"bounds broken %@", hasLoadedView);
  XCTAssertTrue(CGPointEqualToPoint(CGPointMake(10, 65), node.position), @"position broken %@", hasLoadedView);
  XCTAssertEqual((CGFloat)5.6, node.zPosition, @"zPosition broken %@", hasLoadedView);
  XCTAssertEqual(.5f, node.contentsScale, @"contentsScale broken %@", hasLoadedView);
  XCTAssertTrue(CATransform3DEqualToTransform(CATransform3DMakeScale(0.5, 0.5, 1.0), node.transform), @"transform broken %@", hasLoadedView);
  XCTAssertTrue(CATransform3DEqualToTransform(CATransform3DMakeTranslation(1337, 7357, 7007), node.subnodeTransform), @"subnodeTransform broken %@", hasLoadedView);
  XCTAssertEqualObjects([UIColor clearColor], node.backgroundColor, @"backgroundColor broken %@", hasLoadedView);
  XCTAssertEqual(UIViewContentModeBottom, node.contentMode, @"contentMode broken %@", hasLoadedView);
  XCTAssertEqual([[UIColor cyanColor] CGColor], node.shadowColor, @"shadowColor broken %@", hasLoadedView);
  XCTAssertEqual(.5f, node.shadowOpacity, @"shadowOpacity broken %@", hasLoadedView);
  XCTAssertTrue(CGSizeEqualToSize(CGSizeMake(1.0f, 1.0f), node.shadowOffset), @"shadowOffset broken %@", hasLoadedView);
  XCTAssertEqual(.5f, node.shadowRadius, @"shadowRadius broken %@", hasLoadedView);
  XCTAssertEqual(.5f, node.borderWidth, @"borderWidth broken %@", hasLoadedView);
  XCTAssertEqual([[UIColor orangeColor] CGColor], node.borderColor, @"borderColor broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.displaySuspended, @"displaySuspended broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.displaysAsynchronously, @"displaySuspended broken %@", hasLoadedView);
  XCTAssertEqual(YES, node.asyncdisplaykit_asyncTransactionContainer, @"asyncTransactionContainer broken %@", hasLoadedView);
  XCTAssertEqual(NO, node.userInteractionEnabled, @"userInteractionEnabled broken %@", hasLoadedView);
  XCTAssertEqual((BOOL)!isLayerBacked, node.exclusiveTouch, @"exclusiveTouch broken %@", hasLoadedView);
  XCTAssertEqualObjects(@"quack like a duck", node.name, @"name broken %@", hasLoadedView);

  if (!isLayerBacked) {
    XCTAssertEqual(UIViewAutoresizingFlexibleLeftMargin, node.autoresizingMask, @"autoresizingMask %@", hasLoadedView);
    XCTAssertEqual(NO, node.autoresizesSubviews, @"autoresizesSubviews broken %@", hasLoadedView);
    XCTAssertEqual(YES, node.isAccessibilityElement, @"accessibilityElement broken %@", hasLoadedView);
    XCTAssertEqualObjects(@"Ship love", node.accessibilityLabel, @"accessibilityLabel broken %@", hasLoadedView);
    XCTAssertEqualObjects(@"Awesome things will happen", node.accessibilityHint, @"accessibilityHint broken %@", hasLoadedView);
    XCTAssertEqualObjects(@"1 of 2", node.accessibilityValue, @"accessibilityValue broken %@", hasLoadedView);
    XCTAssertEqual(UIAccessibilityTraitSelected | UIAccessibilityTraitButton, node.accessibilityTraits, @"accessibilityTraits broken %@", hasLoadedView);
    XCTAssertTrue(CGRectEqualToRect(CGRectMake(1, 2, 3, 4), node.accessibilityFrame), @"accessibilityFrame broken %@", hasLoadedView);
    XCTAssertEqualObjects(@"mas", node.accessibilityLanguage, @"accessibilityLanguage broken %@", hasLoadedView);
    XCTAssertEqual(YES, node.accessibilityElementsHidden, @"accessibilityElementsHidden broken %@", hasLoadedView);
    XCTAssertEqual(YES, node.accessibilityViewIsModal, @"accessibilityViewIsModal broken %@", hasLoadedView);
    XCTAssertEqual(YES, node.shouldGroupAccessibilityChildren, @"shouldGroupAccessibilityChildren broken %@", hasLoadedView);
  }
}

- (void)checkSimpleBridgePropertiesSetPropagate:(BOOL)isLayerBacked
{
  __block ASDisplayNode *node = nil;

  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] init];
    node.layerBacked = isLayerBacked;

    node.contents = (id)[self bogusImage].CGImage;
    node.clipsToBounds = YES;
    node.opaque = NO;
    node.needsDisplayOnBoundsChange = YES;
    node.allowsEdgeAntialiasing = YES;
    node.edgeAntialiasingMask = (kCALayerLeftEdge | kCALayerTopEdge);
    node.hidden = YES;
    node.alpha = .5f;
    node.position = CGPointMake(10, 65);
    node.zPosition = 5.6;
    node.bounds = CGRectMake(10, 15, 42, 115.2);
    node.contentsScale = .5f;
    node.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
    node.subnodeTransform = CATransform3DMakeTranslation(1337, 7357, 7007);
    node.backgroundColor = [UIColor clearColor];
    node.contentMode = UIViewContentModeBottom;
    node.shadowColor = [[UIColor cyanColor] CGColor];
    node.shadowOpacity = .5f;
    node.shadowOffset = CGSizeMake(1.0f, 1.0f);
    node.shadowRadius = .5f;
    node.borderWidth = .5f;
    node.borderColor = [[UIColor orangeColor] CGColor];
    node.displaySuspended = YES;
    node.displaysAsynchronously = NO;
    node.asyncdisplaykit_asyncTransactionContainer = YES;
    node.userInteractionEnabled = NO;
    node.name = @"quack like a duck";

    if (!isLayerBacked) {
      node.exclusiveTouch = YES;
      node.autoresizesSubviews = NO;
      node.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
      node.isAccessibilityElement = YES;
      node.accessibilityLabel = @"Ship love";
      node.accessibilityHint = @"Awesome things will happen";
      node.accessibilityValue = @"1 of 2";
      node.accessibilityTraits = UIAccessibilityTraitSelected | UIAccessibilityTraitButton;
      node.accessibilityFrame = CGRectMake(1, 2, 3, 4);
      node.accessibilityLanguage = @"mas";
      node.accessibilityElementsHidden = YES;
      node.accessibilityViewIsModal = YES;
      node.shouldGroupAccessibilityChildren = YES;
    }
  }];

  // Assert that the values can be fetched from the node before the view is realized.
  [self checkValuesMatchSetValues:node isLayerBacked:isLayerBacked];

  // Assert that the realized view/layer have the correct values.
  [node layer];

  [self checkValuesMatchSetValues:node isLayerBacked:isLayerBacked];

  // As a final sanity check, change a value on the realized view and ensure it is fetched through the node.
  if (isLayerBacked) {
    node.layer.hidden = NO;
  } else {
    node.view.hidden = NO;
  }
  XCTAssertEqual(NO, node.hidden, @"After the view is realized, the node should delegate properties to the view.");
}

// Set each of the simple bridged UIView properties to a non-default value off-thread, then
// assert that they are correct on the node and propagated to the UIView realized on-thread.
- (void)testSimpleUIViewBridgePropertiesSetOffThreadPropagate
{
  [self checkSimpleBridgePropertiesSetPropagate:NO];
}

- (void)testSimpleCALayerBridgePropertiesSetOffThreadPropagate
{
  [self checkSimpleBridgePropertiesSetPropagate:YES];
}

- (void)testPropertiesSetOffThreadBeforeLoadingExternalView
{
  UIView *view = [[UIDisplayNodeTestView alloc] init];

  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] initWithViewBlock:^{
      return view;
    }];
    node.backgroundColor = [UIColor blueColor];
    node.frame = CGRectMake(10, 20, 30, 40);
    node.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    node.userInteractionEnabled = YES;
  }];

  [self checkExternalViewAppliedPropertiesMatch:node];
}

- (void)testPropertiesSetOnThreadAfterLoadingExternalView
{
  UIView *view = [[UIDisplayNodeTestView alloc] init];
  ASDisplayNode *node = [[ASDisplayNode alloc] initWithViewBlock:^{
    return view;
  }];

  // Load the backing view first
  [node view];

  node.backgroundColor = [UIColor blueColor];
  node.frame = CGRectMake(10, 20, 30, 40);
  node.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  node.userInteractionEnabled = YES;

  [self checkExternalViewAppliedPropertiesMatch:node];
}

- (void)checkExternalViewAppliedPropertiesMatch:(ASDisplayNode *)node
{
  UIView *view = node.view;

  XCTAssertEqualObjects([UIColor blueColor], view.backgroundColor, @"backgroundColor not propagated to view");
  XCTAssertTrue(CGRectEqualToRect(CGRectMake(10, 20, 30, 40), view.frame), @"frame not propagated to view");
  XCTAssertEqual(UIViewAutoresizingFlexibleWidth, view.autoresizingMask, @"autoresizingMask not propagated to view");
  XCTAssertEqual(YES, view.userInteractionEnabled, @"userInteractionEnabled not propagated to view");
}

- (void)testPropertiesSetOffThreadBeforeLoadingExternalLayer
{
  CALayer *layer = [[CAShapeLayer alloc] init];

  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] initWithLayerBlock:^{
      return layer;
    }];
    node.backgroundColor = [UIColor blueColor];
    node.frame = CGRectMake(10, 20, 30, 40);
  }];

  [self checkExternalLayerAppliedPropertiesMatch:node];
}

- (void)testPropertiesSetOnThreadAfterLoadingExternalLayer
{
  CALayer *layer = [[CAShapeLayer alloc] init];
  ASDisplayNode *node = [[ASDisplayNode alloc] initWithLayerBlock:^{
    return layer;
  }];

  // Load the backing layer first
  [node layer];

  node.backgroundColor = [UIColor blueColor];
  node.frame = CGRectMake(10, 20, 30, 40);

  [self checkExternalLayerAppliedPropertiesMatch:node];
}

- (void)checkExternalLayerAppliedPropertiesMatch:(ASDisplayNode *)node
{
  CALayer *layer = node.layer;

  XCTAssertTrue(CGColorEqualToColor([UIColor blueColor].CGColor, layer.backgroundColor), @"backgroundColor not propagated to layer");
  XCTAssertTrue(CGRectEqualToRect(CGRectMake(10, 20, 30, 40), layer.frame), @"frame not propagated to layer");
}


// Perform parallel updates of a standard UIView/CALayer and an ASDisplayNode and ensure they are equivalent.
- (void)testDeriveFrameFromBoundsPositionAnchorPoint
{
  UIView *plainView = [[UIView alloc] initWithFrame:CGRectZero];
  plainView.layer.anchorPoint = CGPointMake(0.25f, 0.75f);
  plainView.layer.position = CGPointMake(10, 20);
  plainView.layer.bounds = CGRectMake(0, 0, 60, 80);

  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] init];
    node.anchorPoint = CGPointMake(0.25f, 0.75f);
    node.bounds = CGRectMake(0, 0, 60, 80);
    node.position = CGPointMake(10, 20);
  }];

  XCTAssertTrue(CGRectEqualToRect(plainView.frame, node.frame), @"Node frame should match UIView frame before realization.");
  XCTAssertTrue(CGRectEqualToRect(plainView.frame, node.view.frame), @"Realized view frame should match UIView frame.");
}

// Perform parallel updates of a standard UIView/CALayer and an ASDisplayNode and ensure they are equivalent.
- (void)testSetFrameSetsBoundsPosition
{
  UIView *plainView = [[UIView alloc] initWithFrame:CGRectZero];
  plainView.layer.anchorPoint = CGPointMake(0.25f, 0.75f);
  plainView.layer.frame = CGRectMake(10, 20, 60, 80);

  __block ASDisplayNode *node = nil;
  [self executeOffThread:^{
    node = [[ASDisplayNode alloc] init];
    node.anchorPoint = CGPointMake(0.25f, 0.75f);
    node.frame = CGRectMake(10, 20, 60, 80);
  }];

  XCTAssertTrue(CGPointEqualToPoint(plainView.layer.position, node.position), @"Node position should match UIView position before realization.");
  XCTAssertTrue(CGRectEqualToRect(plainView.layer.bounds, node.bounds), @"Node bounds should match UIView bounds before realization.");
  XCTAssertTrue(CGPointEqualToPoint(plainView.layer.position, node.view.layer.position), @"Realized view position should match UIView position before realization.");
  XCTAssertTrue(CGRectEqualToRect(plainView.layer.bounds, node.view.layer.bounds), @"Realized view bounds should match UIView bounds before realization.");
}

- (void)testDisplayNodePointConversionWithFrames
{
  ASDisplayNode *node = nil;
  ASDisplayNode *innerNode = nil;

  // Setup
  CGPoint originalPoint = CGPointZero, convertedPoint = CGPointZero, correctPoint = CGPointZero;
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* outer node's coordinate space to inner node's coordinate space
  node.frame = CGRectMake(100, 100, 100, 100);
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(105, 105), correctPoint = CGPointMake(95, 95);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:node selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* inner node's coordinate space to outer node's coordinate space
  node.frame = CGRectMake(100, 100, 100, 100);
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(5, 5), correctPoint = CGPointMake(15, 15);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:node];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in inner node's coordinate space *TO* outer node's coordinate space
  node.frame = CGRectMake(100, 100, 100, 100);
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(95, 95), correctPoint = CGPointMake(105, 105);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:node selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in outer node's coordinate space *TO* inner node's coordinate space
  node.frame = CGRectMake(0, 0, 100, 100);
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(5, 5), correctPoint = CGPointMake(-5, -5);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:node];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));
}

// Test conversions when bounds is not null.
// NOTE: Esoteric values were picked to facilitate visual inspection by demonstrating the relevance of certain numbers and lack of relevance of others
- (void)testDisplayNodePointConversionWithNonZeroBounds
{
  ASDisplayNode *node = nil;
  ASDisplayNode *innerNode = nil;

  // Setup
  CGPoint originalPoint = CGPointZero, convertedPoint = CGPointZero, correctPoint = CGPointZero;
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* outer node's coordinate space to inner node's coordinate space
  node.anchorPoint = CGPointZero;
  innerNode.anchorPoint = CGPointZero;
  node.bounds = CGRectMake(20, 20, 100, 100);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(42, 42), correctPoint = CGPointMake(36, 36);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:node selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* inner node's coordinate space to outer node's coordinate space
  node.anchorPoint = CGPointZero;
  innerNode.anchorPoint = CGPointZero;
  node.bounds = CGRectMake(-1000, -1000, 1337, 1337);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 200, 200);
  originalPoint = CGPointMake(5, 5), correctPoint = CGPointMake(11, 11);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:node];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in inner node's coordinate space *TO* outer node's coordinate space
  node.anchorPoint = CGPointZero;
  innerNode.anchorPoint = CGPointZero;
  node.bounds = CGRectMake(20, 20, 100, 100);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(36, 36), correctPoint = CGPointMake(42, 42);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:node selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in outer node's coordinate space *TO* inner node's coordinate space
  node.anchorPoint = CGPointZero;
  innerNode.anchorPoint = CGPointZero;
  node.bounds = CGRectMake(-1000, -1000, 1337, 1337);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 200, 200);
  originalPoint = CGPointMake(11, 11), correctPoint = CGPointMake(5, 5);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:node];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));
}

// Test conversions when the anchorPoint is not {0.0, 0.0}.
- (void)testDisplayNodePointConversionWithNonZeroAnchorPoint
{
  ASDisplayNode *node = nil;
  ASDisplayNode *innerNode = nil;

  // Setup
  CGPoint originalPoint = CGPointZero, convertedPoint = CGPointZero, correctPoint = CGPointZero;
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* outer node's coordinate space to inner node's coordinate space
  node.bounds = CGRectMake(20, 20, 100, 100);
  innerNode.anchorPoint = CGPointMake(0.75, 1);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(42, 42), correctPoint = CGPointMake(51, 56);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:node selfNode:innerNode];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(convertedPoint, correctPoint, 0.001), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point *FROM* inner node's coordinate space to outer node's coordinate space
  node.bounds = CGRectMake(-1000, -1000, 1337, 1337);
  innerNode.anchorPoint = CGPointMake(0.3, 0.3);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 200, 200);
  originalPoint = CGPointMake(55, 55), correctPoint = CGPointMake(1, 1);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:node];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(convertedPoint, correctPoint, 0.001), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in inner node's coordinate space *TO* outer node's coordinate space
  node.bounds = CGRectMake(20, 20, 100, 100);
  innerNode.anchorPoint = CGPointMake(0.75, 1);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(51, 56), correctPoint = CGPointMake(42, 42);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:node selfNode:innerNode];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(convertedPoint, correctPoint, 0.001), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));

  // Setup
  node = [[[ASDisplayNode alloc] init] autorelease], innerNode = [[[ASDisplayNode alloc] init] autorelease];
  [node addSubnode:innerNode];

  // Convert point in outer node's coordinate space *TO* inner node's coordinate space
  node.bounds = CGRectMake(-1000, -1000, 1337, 1337);
  innerNode.anchorPoint = CGPointMake(0.3, 0.3);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 200, 200);
  originalPoint = CGPointMake(1, 1), correctPoint = CGPointMake(55, 55);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:node];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(convertedPoint, correctPoint, 0.001), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));
}

- (void)testDisplayNodePointConversionAgainstSelf {
  ASDisplayNode *innerNode = nil;
  CGPoint originalPoint = CGPointZero, convertedPoint = CGPointZero;

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(105, 105);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:innerNode];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(convertedPoint, originalPoint, 0.001), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(42, 42);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, originalPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.anchorPoint = CGPointMake(0.3, 0.3);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 200, 200);
  originalPoint = CGPointMake(55, 55);
  convertedPoint = [self checkConvertPoint:originalPoint fromNode:innerNode selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, originalPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.frame = CGRectMake(10, 10, 20, 20);
  originalPoint = CGPointMake(95, 95);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, originalPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(36, 36);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, originalPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));

  innerNode = [[[ASDisplayNode alloc] init] autorelease];
  innerNode.anchorPoint = CGPointMake(0.75, 1);
  innerNode.position = CGPointMake(23, 23);
  innerNode.bounds = CGRectMake(17, 17, 20, 20);
  originalPoint = CGPointMake(51, 56);
  convertedPoint = [self checkConvertPoint:originalPoint toNode:innerNode selfNode:innerNode];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, originalPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(convertedPoint));
}

- (void)testDisplayNodePointConversionFailureFromDisjointHierarchies
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  ASDisplayNode *childNode = [[ASDisplayNode alloc] init];
  ASDisplayNode *otherNode = [[ASDisplayNode alloc] init];
  [node addSubnode:childNode];

  XCTAssertNoThrow([self checkConvertPoint:CGPointZero fromNode:node selfNode:childNode], @"Assertion should have succeeded; nodes are in the same hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero fromNode:node selfNode:otherNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero fromNode:childNode selfNode:otherNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");

  XCTAssertNoThrow([self checkConvertPoint:CGPointZero fromNode:childNode selfNode:node], @"Assertion should have succeeded; nodes are in the same hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero fromNode:otherNode selfNode:node], @"Assertion should have failed for nodes that are not in the same node hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero fromNode:otherNode selfNode:childNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");

  XCTAssertNoThrow([self checkConvertPoint:CGPointZero toNode:node selfNode:childNode], @"Assertion should have succeeded; nodes are in the same hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero toNode:node selfNode:otherNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero toNode:childNode selfNode:otherNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");

  XCTAssertNoThrow([self checkConvertPoint:CGPointZero toNode:childNode selfNode:node], @"Assertion should have succeeded; nodes are in the same hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero toNode:otherNode selfNode:node], @"Assertion should have failed for nodes that are not in the same node hierarchy");
  XCTAssertThrows([self checkConvertPoint:CGPointZero toNode:otherNode selfNode:childNode], @"Assertion should have failed for nodes that are not in the same node hierarchy");

  [node release];
  [childNode release];
  [otherNode release];
}

- (void)testDisplayNodePointConversionOnDeepHierarchies
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];

  // 7 deep (six below root); each one positioned at position = (1, 1)
  _addTonsOfSubnodes(node, 2, 6, ^(ASDisplayNode *createdNode) {
    createdNode.position = CGPointMake(1, 1);
  });

  ASDisplayNode *deepSubNode = [self _getDeepSubnodeForRoot:node withIndices:@[@1, @1, @1, @1, @1, @1]];

  CGPoint originalPoint = CGPointMake(55, 55);
  CGPoint correctPoint = CGPointMake(61, 61);
  CGPoint convertedPoint = [deepSubNode convertPoint:originalPoint toNode:node];
  XCTAssertTrue(CGPointEqualToPoint(convertedPoint, correctPoint), @"Unexpected point conversion result. Point: %@ Expected conversion: %@ Actual conversion: %@", NSStringFromCGPoint(originalPoint), NSStringFromCGPoint(correctPoint), NSStringFromCGPoint(convertedPoint));
}

// Adds nodes (breadth-first rather than depth-first addition)
static void _addTonsOfSubnodes(ASDisplayNode *parent, NSUInteger fanout, NSUInteger depth, void (^onCreate)(ASDisplayNode *createdNode)) {
  if (depth == 0) {
    return;
  }

  for (NSUInteger i = 0; i < fanout; i++) {
    ASDisplayNode *subnode = [[ASDisplayNode alloc] init];
    [parent addSubnode:subnode];
    onCreate(subnode);
    [subnode release];
  }
  for (NSUInteger i = 0; i < fanout; i++) {
    _addTonsOfSubnodes(parent.subnodes[i], fanout, depth - 1, onCreate);
  }
}

// Convenience function for getting a node deep within a node hierarchy
- (ASDisplayNode *)_getDeepSubnodeForRoot:(ASDisplayNode *)root withIndices:(NSArray *)indexArray {
  if ([indexArray count] == 0) {
    return root;
  }

  NSArray *subnodes = root.subnodes;
  if ([subnodes count] == 0) {
    XCTFail(@"Node hierarchy isn't deep enough for given index array");
  }

  NSUInteger index = [indexArray[0] unsignedIntegerValue];
  NSArray *otherIndices = [indexArray subarrayWithRange:NSMakeRange(1, [indexArray count] -1)];

  return [self _getDeepSubnodeForRoot:subnodes[index] withIndices:otherIndices];
}

static inline BOOL _CGPointEqualToPointWithEpsilon(CGPoint point1, CGPoint point2, CGFloat epsilon) {
  CGFloat absEpsilon =  fabs(epsilon);
  BOOL xOK = fabs(point1.x - point2.x) < absEpsilon;
  BOOL yOK = fabs(point1.y - point2.y) < absEpsilon;
  return xOK && yOK;
}

- (CGPoint)checkConvertPoint:(CGPoint)point fromNode:(ASDisplayNode *)fromNode selfNode:(ASDisplayNode *)toNode
{
  CGPoint nodeConversion = [toNode convertPoint:point fromNode:fromNode];

  UIView *fromView = fromNode.view;
  UIView *toView = toNode.view;
  CGPoint viewConversion = [toView convertPoint:point fromView:fromView];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(nodeConversion, viewConversion, 0.001), @"Conversion mismatch: node: %@ view: %@", NSStringFromCGPoint(nodeConversion), NSStringFromCGPoint(viewConversion));
  return nodeConversion;
}

- (CGPoint)checkConvertPoint:(CGPoint)point toNode:(ASDisplayNode *)toNode selfNode:(ASDisplayNode *)fromNode
{
  CGPoint nodeConversion = [fromNode convertPoint:point toNode:toNode];

  UIView *fromView = fromNode.view;
  UIView *toView = toNode.view;
  CGPoint viewConversion = [fromView convertPoint:point toView:toView];
  XCTAssertTrue(_CGPointEqualToPointWithEpsilon(nodeConversion, viewConversion, 0.001), @"Conversion mismatch: node: %@ view: %@", NSStringFromCGPoint(nodeConversion), NSStringFromCGPoint(viewConversion));
  return nodeConversion;
}

- (void)executeOffThread:(void (^)(void))block
{
  __block BOOL blockExecuted = NO;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  dispatch_async(queue, ^{
    block();
    blockExecuted = YES;
    dispatch_semaphore_signal(sema);
  });
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  dispatch_release(sema);
  XCTAssertTrue(blockExecuted, @"Block did not finish executing. Timeout or exception?");
}

- (void)testReferenceCounting
{
  __block BOOL didDealloc = NO;

  ASTestDisplayNode *node = [[ASTestDisplayNode alloc] init];
  node.willDeallocBlock = ^(ASDisplayNode *n){
    didDealloc = YES;
  };

  // verify initial
  XCTAssertTrue(1 == node.retainCount, @"unexpected retain count:%tu", node.retainCount);

  // verify increment
  [node retain];
  XCTAssertTrue(2 == node.retainCount, @"unexpected retain count:%tu", node.retainCount);

  // verify dealloc
  [node release];
  [node release];
  XCTAssertTrue(didDealloc, @"unexpected node lifetime:%@", node);
}

- (void)testAddingNodeToHierarchyRetainsNode
{
  ASTestDisplayNode *node = [[ASTestDisplayNode alloc] init];

  __block BOOL didDealloc = NO;
  node.willDeallocBlock = ^(ASDisplayNode *n){
    didDealloc = YES;
  };

  // verify initial
  XCTAssertTrue(1 == node.retainCount, @"unexpected retain count:%tu", node.retainCount);

  UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
  [v addSubview:node.view];

  XCTAssertTrue(2 == node.retainCount, @"view should retain node when added. retain count:%tu", node.retainCount);

  [node release];
  XCTAssertTrue(1 == node.retainCount, @"unexpected retain count:%tu", node.retainCount);

  [node.view removeFromSuperview];
  XCTAssertTrue(didDealloc, @"unexpected node lifetime:%@", node);
  [v release];
}

- (void)testAddingSubnodeDoesNotCreateRetainCycle
{
  ASTestDisplayNode *node = [[ASTestDisplayNode alloc] init];

  __block BOOL didDealloc = NO;
  node.willDeallocBlock = ^(ASDisplayNode *n){
    didDealloc = YES;
  };

  ASDisplayNode *subnode = [[ASDisplayNode alloc] init];

  // verify initial
  XCTAssertTrue(1 == node.retainCount, @"unexpected retain count:%tu", node.retainCount);
  XCTAssertTrue(1 == subnode.retainCount, @"unexpected retain count:%tu", subnode.retainCount);

  [node addSubnode:subnode];
  XCTAssertTrue(2 == subnode.retainCount, @"node should retain subnode when added. retain count:%tu", node.retainCount);
  XCTAssertTrue(1 == node.retainCount, @"subnode should not retain node when added. retain count:%tu", node.retainCount);

  [subnode release];
  XCTAssertTrue(1 == subnode.retainCount, @"subnode should be retained by node. retain count:%tu", subnode.retainCount);

  [node release];
  XCTAssertTrue(didDealloc, @"unexpected node lifetime:%@", node);
}

- (void)testMainThreadDealloc
{
  __block BOOL didDealloc = NO;

  [self executeOffThread:^{
    @autoreleasepool {
      ASTestDisplayNode *node = [[ASTestDisplayNode alloc] init];
      node.willDeallocBlock = ^(ASDisplayNode *n){
        XCTAssertTrue([NSThread isMainThread], @"unexpected node dealloc %@ %@", n, [NSThread currentThread]);
        didDealloc = YES;
      };
      [node release];
    }
  }];

  // deallocation should be queued on the main runloop; give it a chance
  ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{ return didDealloc; });
  XCTAssertTrue(didDealloc, @"unexpected node lifetime");
}

- (void)testSubnodes
{
  ASDisplayNode *parent = [[ASDisplayNode alloc] init];
  XCTAssertNoThrow([parent addSubnode:nil], @"Don't try to add nil, but we'll deal.");
  XCTAssertNoThrow([parent addSubnode:parent], @"Not good, test that we recover");
  XCTAssertEqual(0u, parent.subnodes.count, @"We shouldn't have any subnodes");
}

- (void)testReplaceSubnodeNoView
{
  [self checkReplaceSubnodeWithView:NO layerBacked:NO];
}

- (void)testReplaceSubnodeNoLayer
{
  [self checkReplaceSubnodeWithView:NO layerBacked:YES];
}

- (void)testReplaceSubnodeView
{
  [self checkReplaceSubnodeWithView:YES layerBacked:NO];
}

- (void)testReplaceSubnodeLayer
{
  [self checkReplaceSubnodeWithView:YES layerBacked:YES];
}


- (void)checkReplaceSubnodeWithView:(BOOL)loaded layerBacked:(BOOL)isLayerBacked
{
  DeclareNodeNamed(parent);
  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);

  for (ASDisplayNode *n in @[parent, a, b, c]) {
    n.layerBacked = isLayerBacked;
  }

  [parent addSubnode:a];
  [parent addSubnode:b];
  [parent addSubnode:c];

  if (loaded) {
    [parent layer];
  }

  DeclareNodeNamed(d);
  if (loaded) {
    XCTAssertFalse(d.nodeLoaded, @"Should not yet be loaded");
  }

  // Shut the type mismatch up
  ASDisplayNode *nilParent = nil;

  // Check initial state
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"initial state");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Check replace 0th
  [parent replaceSubnode:a withSubnode:d];

  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"d,b,c", @"after replace 0th");
  XCTAssertNodesHaveParent(parent, d, b, c);
  XCTAssertNodesHaveParent(nilParent, a);
  if (loaded) {
    XCTAssertNodesLoaded(d);
  }

  [parent replaceSubnode:d withSubnode:a];

  // Check replace 1st
  [parent replaceSubnode:b withSubnode:d];

  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,d,c", @"Replace");
  XCTAssertNodesHaveParent(parent, a, c, d);
  XCTAssertNodesHaveParent(nilParent, b);

  [parent replaceSubnode:d withSubnode:b];

  // Check replace 2nd
  [parent replaceSubnode:c withSubnode:d];

  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,d", @"Replace");
  XCTAssertNodesHaveParent(parent, a, b, d);
  XCTAssertNodesHaveParent(nilParent, c);

  [parent replaceSubnode:d withSubnode:c];

  //Check initial again
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"check should back to initial");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Check replace 0th with 2nd
  [parent replaceSubnode:a withSubnode:c];

  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,b", @"After replace 0th");
  XCTAssertNodesHaveParent(parent, c, b);
  XCTAssertNodesHaveParent(nilParent, a,d);

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
  [d release];
}

- (void)testInsertSubnodeAtIndexView
{
  [self checkInsertSubnodeAtIndexWithViewLoaded:YES layerBacked:NO];
}

- (void)testInsertSubnodeAtIndexLayer
{
  [self checkInsertSubnodeAtIndexWithViewLoaded:YES layerBacked:YES];
}

- (void)testInsertSubnodeAtIndexNoView
{
  [self checkInsertSubnodeAtIndexWithViewLoaded:NO layerBacked:NO];
}

- (void)testInsertSubnodeAtIndexNoLayer
{
  [self checkInsertSubnodeAtIndexWithViewLoaded:NO layerBacked:YES];
}

- (void)checkInsertSubnodeAtIndexWithViewLoaded:(BOOL)loaded layerBacked:(BOOL)isLayerBacked
{
  DeclareNodeNamed(parent);
  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);

  for (ASDisplayNode *v in @[parent, a, b, c]) {
    v.layerBacked = isLayerBacked;
  }

  // Load parent
  if (loaded) {
    (void)[parent layer];
  }

  // Add another subnode to test creation after parent is loaded
  DeclareNodeNamed(d);
  d.layerBacked = isLayerBacked;
  if (loaded) {
    XCTAssertFalse(d.nodeLoaded, @"Should not yet be loaded");
  }

  // Shut the type mismatch up
  ASDisplayNode *nilParent = nil;

  // Check initial state
  XCTAssertEqual(0u, parent.subnodes.count, @"Should have the right subnode count");

  // Check insert at 0th () => (a,b,c)
  [parent insertSubnode:c atIndex:0];
  [parent insertSubnode:b atIndex:0];
  [parent insertSubnode:a atIndex:0];

  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"initial state");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  if (loaded) {
    XCTAssertNodesLoaded(a, b, c);
  } else {
    XCTAssertNodesNotLoaded(a, b, c);
  }

  // Check insert at 1st (a,b,c) => (a,d,b,c)
  [parent insertSubnode:d atIndex:1];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,d,b,c", @"initial state");
  XCTAssertNodesHaveParent(parent, a, b, c, d);
  if (loaded) {
    XCTAssertNodesLoaded(d);
  }

  // Reset
  [d removeFromSupernode];
  XCTAssertEqual(3u, parent.subnodes.count, @"Should have the right subnode count");
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"Bad removal of d");
  XCTAssertNodesHaveParent(nilParent, d);

  // Check insert at last position
  [parent insertSubnode:d atIndex:3];

  XCTAssertEqual(4u, parent.subnodes.count, @"Should have the right subnode count");
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c,d", @"insert at last position.");
  XCTAssertNodesHaveParent(parent, a, b, c, d);

  // Reset
  [d removeFromSupernode];
  XCTAssertEqual(3u, parent.subnodes.count, @"Should have the right subnode count");
  XCTAssertEqualObjects(nilParent, d.supernode, @"d's parent is messed up");


  // Check insert at invalid index
  XCTAssertThrows([parent insertSubnode:d atIndex:NSNotFound], @"Should not allow insertion at invalid index");
  XCTAssertThrows([parent insertSubnode:d atIndex:-1], @"Should not allow insertion at invalid index");

  // Should have same state as before
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"Funny business should not corrupt state");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Check reordering existing subnodes with the insert API
  // Move c to front
  [parent insertSubnode:c atIndex:0];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,a,b", @"Move to front when already a subnode");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Move c to middle
  [parent insertSubnode:c atIndex:1];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Move c to middle");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Insert c at the index it's already at
  [parent insertSubnode:c atIndex:1];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Funny business should not corrupt state");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  // Insert c at 0th when it's already in the array
  [parent insertSubnode:c atIndex:2];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b,c", @"Funny business should not corrupt state");
  XCTAssertNodesHaveParent(parent, a, b, c);
  XCTAssertNodesHaveParent(nilParent, d);

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
  [d release];
}

// This tests our resiliancy to having other views and layers inserted into our view or layer
- (void)testInsertSubviewAtIndexWithMeddlingViewsAndLayersViewBacked
{
  ASDisplayNode *parent = [[ASDisplayNode alloc] init];

  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);
  DeclareViewNamed(d);
  DeclareLayerNamed(e);

  [parent layer];

  // (a,b)
  [parent addSubnode:a];
  [parent addSubnode:b];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,b", @"Didn't match");

  // (a,b) => (a,d,b)
  [parent.view insertSubview:d aboveSubview:a.view];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,d,b", @"Didn't match");

  // (a,d,b) => (a,e,d,b)
  [parent.layer insertSublayer:e above:a.layer];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,e,d,b", @"Didn't match");

  // (a,e,d,b) => (a,e,d,c,b)
  [parent insertSubnode:c belowSubnode:b];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,e,d,c,b", @"Didn't match");

  XCTAssertEqual(3u, parent.subnodes.count, @"Should have the right subnode count");
  XCTAssertEqual(4u, parent.view.subviews.count, @"Should have the right subview count");
  XCTAssertEqual(5u, parent.layer.sublayers.count, @"Should have the right sublayer count");

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
  [d release];
}

- (void)testAppleBugInsertSubview
{
  DeclareViewNamed(parent);

  DeclareLayerNamed(aa);
  DeclareLayerNamed(ab);
  DeclareViewNamed(a);
  DeclareLayerNamed(ba);
  DeclareLayerNamed(bb);
  DeclareLayerNamed(bc);
  DeclareLayerNamed(bd);
  DeclareViewNamed(c);
  DeclareViewNamed(d);
  DeclareLayerNamed(ea);
  DeclareLayerNamed(eb);
  DeclareLayerNamed(ec);

  [parent.layer addSublayer:aa];
  [parent.layer addSublayer:ab];
  [parent addSubview:a];
  [parent.layer addSublayer:ba];
  [parent.layer addSublayer:bb];
  [parent.layer addSublayer:bc];
  [parent.layer addSublayer:bd];
  [parent addSubview:d];
  [parent.layer addSublayer:ea];
  [parent.layer addSublayer:eb];
  [parent.layer addSublayer:ec];

  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"aa,ab,a,ba,bb,bc,bd,d,ea,eb,ec", @"Should be in order");

  // Should insert at SUBVIEW index 1, right??
  [parent insertSubview:c atIndex:1];

  // You would think that this would be true, but instead it inserts it at the SUBLAYER index 1
//  XCTAssertEquals([parent.subviews indexOfObjectIdenticalTo:c], 1u, @"Should have index 1 after insert");
//  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"aa,ab,a,ba,bb,bc,bd,c,d,ea,eb,ec", @"Should be in order");

  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"aa,c,ab,a,ba,bb,bc,bd,d,ea,eb,ec", @"Apple has fixed insertSubview:atIndex:. You must update insertSubnode: etc. APIS to accomidate this.");
}

// This tests our resiliancy to having other views and layers inserted into our view or layer
- (void)testInsertSubviewAtIndexWithMeddlingView
{
  DeclareNodeNamed(parent);
  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);
  DeclareViewNamed(d);
  DeclareLayerNamed(e);

  [parent layer];

  // (a,b)
  [parent addSubnode:a];
  [parent addSubnode:b];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,b", @"Didn't match");

  // (a,b) => (a,d,b)
  [parent.view insertSubview:d aboveSubview:a.view];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,d,b", @"Didn't match");

  // (a,e,d,b) => (a,d,>c<,b)
  [parent insertSubnode:c belowSubnode:b];
  XCTAssertEqualObjects(orderStringFromSublayers(parent.layer), @"a,d,c,b", @"Didn't match");

  XCTAssertEqual(3u, parent.subnodes.count, @"Should have the right subnode count");
  XCTAssertEqual(4u, parent.view.subviews.count, @"Should have the right subview count");
  XCTAssertEqual(4u, parent.layer.sublayers.count, @"Should have the right sublayer count");

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
  [d release];
}


- (void)testInsertSubnodeBelowWithView
{
  [self checkInsertSubnodeBelowWithView:YES layerBacked:NO];
}

- (void)testInsertSubnodeBelowWithNoView
{
  [self checkInsertSubnodeBelowWithView:NO layerBacked:NO];
}

- (void)testInsertSubnodeBelowWithNoLayer
{
  [self checkInsertSubnodeBelowWithView:NO layerBacked:YES];
}

- (void)testInsertSubnodeBelowWithLayer
{
  [self checkInsertSubnodeBelowWithView:YES layerBacked:YES];
}


- (void)checkInsertSubnodeBelowWithView:(BOOL)loaded layerBacked:(BOOL)isLayerBacked
{
  DeclareNodeNamed(parent);
  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);

  for (ASDisplayNode *v in @[parent, a, b, c]) {
    v.layerBacked = isLayerBacked;
  }

  [parent addSubnode:b];

  if (loaded) {
    [parent layer];
  }

  // Shut the type mismatch up
  ASDisplayNode *nilParent = nil;

  // (b) => (a, b)
  [parent insertSubnode:a belowSubnode:b];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b", @"Incorrect insertion below");
  XCTAssertNodesHaveParent(parent, a, b);
  XCTAssertNodesHaveParent(nilParent, c);

  // (a,b) => (c,a,b)
  [parent insertSubnode:c belowSubnode:a];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,a,b", @"Incorrect insertion below");
  XCTAssertNodesHaveParent(parent, a, b, c);

  // Check insertSubnode with no below
  XCTAssertThrows([parent insertSubnode:b belowSubnode:nil], @"Can't insert below a nil");
  // Check nothing was inserted
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,a,b", @"Incorrect insertion below");


  XCTAssertThrows([parent insertSubnode:nil belowSubnode:nil], @"Can't insert a nil subnode");
  XCTAssertThrows([parent insertSubnode:nil belowSubnode:a], @"Can't insert a nil subnode");

  // Check inserting below when you're already in the array
  // (c,a,b) => (a,c,b)
  [parent insertSubnode:c belowSubnode:b];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Incorrect insertion below");
  XCTAssertNodesHaveParent(parent, a, c, b);

  // Check what happens when you try to insert a node below itself (should do nothing)
  // (a,c,b) => (a,c,b)
  [parent insertSubnode:c belowSubnode:c];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Incorrect insertion below");
  XCTAssertNodesHaveParent(parent, a, c, b);

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
}

- (void)testInsertSubnodeAboveWithView
{
  [self checkInsertSubnodeAboveLoaded:YES layerBacked:NO];
}

- (void)testInsertSubnodeAboveWithNoView
{
  [self checkInsertSubnodeAboveLoaded:NO layerBacked:NO];
}

- (void)testInsertSubnodeAboveWithLayer
{
  [self checkInsertSubnodeAboveLoaded:YES layerBacked:YES];
}

- (void)testInsertSubnodeAboveWithNoLayer
{
  [self checkInsertSubnodeAboveLoaded:NO layerBacked:YES];
}


- (void)checkInsertSubnodeAboveLoaded:(BOOL)loaded layerBacked:(BOOL)isLayerBacked
{
  DeclareNodeNamed(parent);
  DeclareNodeNamed(a);
  DeclareNodeNamed(b);
  DeclareNodeNamed(c);

  for (ASDisplayNode *n in @[parent, a, b, c]) {
    n.layerBacked = isLayerBacked;
  }

  [parent addSubnode:a];

  if (loaded) {
    [parent layer];
  }

  // Shut the type mismatch up
  ASDisplayNode *nilParent = nil;

  // (a) => (a,b)
  [parent insertSubnode:b aboveSubnode:a];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,b", @"Insert subnode above");
  XCTAssertNodesHaveParent(parent, a,b);
  XCTAssertNodesHaveParent(nilParent, c);

  // (a,b) => (a,c,b)
  [parent insertSubnode:c aboveSubnode:a];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"After insert c above a");

  // Check insertSubnode with invalid parameters throws and doesn't change anything
  // (a,c,b) => (a,c,b)
  XCTAssertThrows([parent insertSubnode:b aboveSubnode:nil], @"Can't insert below a nil");
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Check no monkey business");

  XCTAssertThrows([parent insertSubnode:nil aboveSubnode:nil], @"Can't insert a nil subnode");
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Check no monkey business");

  XCTAssertThrows([parent insertSubnode:nil aboveSubnode:a], @"Can't insert a nil subnode");
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"a,c,b", @"Check no monkey business");

  // Check inserting above when you're already in the array
  // (a,c,b) => (c,b,a)
  [parent insertSubnode:a aboveSubnode:b];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,b,a", @"Check inserting above when you're already in the array");
  XCTAssertNodesHaveParent(parent, a, c, b);

  // Check what happens when you try to insert a node above itself (should do nothing)
  // (c,b,a) => (c,b,a)
  [parent insertSubnode:a aboveSubnode:a];
  XCTAssertNodeSubnodeSubviewSublayerOrder(parent, loaded, isLayerBacked, @"c,b,a", @"Insert above self should not change anything");
  XCTAssertNodesHaveParent(parent, a, c, b);

  //TODO: assert that things deallocate immediately and don't have latent autoreleases in here
  [parent release];
  [a release];
  [b release];
  [c release];
}

- (void)testSubnodeAddedBeforeLoadingExternalView
{
  UIView *view = [[UIDisplayNodeTestView alloc] init];

  __block ASDisplayNode *parent = nil;
  __block ASDisplayNode *child = nil;
  [self executeOffThread:^{
    parent = [[ASDisplayNode alloc] initWithViewBlock:^{
      return view;
    }];
    child = [[ASDisplayNode alloc] init];
    [parent addSubnode:child];
  }];

  XCTAssertEqual(1, parent.subnodes.count, @"Parent should have 1 subnode");
  XCTAssertEqualObjects(parent, child.supernode, @"Child has the wrong parent");
  XCTAssertEqual(0, view.subviews.count, @"View shouldn't have any subviews");

  [parent view];

  XCTAssertEqual(1, view.subviews.count, @"View should have 1 subview");
}

- (void)testSubnodeAddedAfterLoadingExternalView
{
  UIView *view = [[UIDisplayNodeTestView alloc] init];
  ASDisplayNode *parent = [[ASDisplayNode alloc] initWithViewBlock:^{
    return view;
  }];

  [parent view];

  ASDisplayNode *child = [[ASDisplayNode alloc] init];
  [parent addSubnode:child];

  XCTAssertEqual(1, parent.subnodes.count, @"Parent should have 1 subnode");
  XCTAssertEqualObjects(parent, child.supernode, @"Child has the wrong parent");
  XCTAssertEqual(1, view.subviews.count, @"View should have 1 subview");
}

- (void)checkBackgroundColorOpaqueRelationshipWithViewLoaded:(BOOL)loaded layerBacked:(BOOL)isLayerBacked
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.layerBacked = isLayerBacked;

  if (loaded) {
    // Force load
    [node layer];
  }

  XCTAssertTrue(node.opaque, @"Node should start opaque");
  XCTAssertTrue(node.layer.opaque, @"Node should start opaque");

  node.backgroundColor = [UIColor clearColor];

  // This could be debated, but at the moment we differ from UIView's behavior to change the other property in response
  XCTAssertTrue(node.opaque, @"Set background color should not have made this not opaque");
  XCTAssertTrue(node.layer.opaque, @"Set background color should not have made this not opaque");

  [node layer];

  XCTAssertTrue(node.opaque, @"Set background color should not have made this not opaque");
  XCTAssertTrue(node.layer.opaque, @"Set background color should not have made this not opaque");

  [node release];
}

- (void)testBackgroundColorOpaqueRelationshipView
{
  [self checkBackgroundColorOpaqueRelationshipWithViewLoaded:YES layerBacked:NO];
}

- (void)testBackgroundColorOpaqueRelationshipLayer
{
  [self checkBackgroundColorOpaqueRelationshipWithViewLoaded:YES layerBacked:YES];
}

- (void)testBackgroundColorOpaqueRelationshipNoView
{
  [self checkBackgroundColorOpaqueRelationshipWithViewLoaded:NO layerBacked:NO];
}

- (void)testBackgroundColorOpaqueRelationshipNoLayer
{
  [self checkBackgroundColorOpaqueRelationshipWithViewLoaded:NO layerBacked:YES];
}

- (void)testInitWithViewClass
{
  ASDisplayNode *scrollNode = [[ASDisplayNode alloc] initWithViewClass:[UIScrollView class]];

  XCTAssertFalse(scrollNode.isLayerBacked, @"Can't be layer backed");
  XCTAssertFalse(scrollNode.nodeLoaded, @"Shouldn't have a view yet");

  scrollNode.frame = CGRectMake(12, 52, 100, 53);
  scrollNode.alpha = 0.5;

  XCTAssertTrue([scrollNode.view isKindOfClass:[UIScrollView class]], @"scrollview should load as expected");
  XCTAssertTrue(CGRectEqualToRect(CGRectMake(12, 52, 100, 53), scrollNode.frame), @"Should have set the frame on the scroll node");
  XCTAssertEqual(0.5f, scrollNode.alpha, @"Alpha not working");
}

- (void)testInitWithLayerClass
{
  ASDisplayNode *transformNode = [[ASDisplayNode alloc] initWithLayerClass:[CATransformLayer class]];

  XCTAssertTrue(transformNode.isLayerBacked, @"Created with layer class => should be layer-backed by default");
  XCTAssertFalse(transformNode.nodeLoaded, @"Shouldn't have a view yet");

  transformNode.frame = CGRectMake(12, 52, 100, 53);
  transformNode.alpha = 0.5;

  XCTAssertTrue([transformNode.layer isKindOfClass:[CATransformLayer class]], @"scrollview should load as expected");
  XCTAssertTrue(CGRectEqualToRect(CGRectMake(12, 52, 100, 53), transformNode.frame), @"Should have set the frame on the scroll node");
  XCTAssertEqual(0.5f, transformNode.alpha, @"Alpha not working");
}

static bool stringContainsPointer(NSString *description, const void *p) {
  return [description rangeOfString:[NSString stringWithFormat:@"%p", p]].location != NSNotFound;
}

- (void)testDebugDescription
{
  // View node has subnodes. Make sure all of the nodes are included in the description
  ASDisplayNode *parent = [[ASDisplayNode alloc] init];

  ASDisplayNode *a = [[[ASDisplayNode alloc] init] autorelease];
  a.layerBacked = YES;
  ASDisplayNode *b = [[[ASDisplayNode alloc] init] autorelease];
  b.layerBacked = YES;
  b.frame = CGRectMake(0, 0, 100, 123);
  ASDisplayNode *c = [[[ASDisplayNode alloc] init] autorelease];

  for (ASDisplayNode *child in @[a, b, c]) {
    [parent addSubnode:child];
  }

  NSString *nodeDescription = [parent displayNodeRecursiveDescription];

  // Make sure [parent recursiveDescription] contains a, b, and c's pointer string
  XCTAssertTrue(stringContainsPointer(nodeDescription, a), @"Layer backed node not present in [parent displayNodeRecursiveDescription]");
  XCTAssertTrue(stringContainsPointer(nodeDescription, b), @"Layer-backed node not present in [parent displayNodeRecursiveDescription]");
  XCTAssertTrue(stringContainsPointer(nodeDescription, c), @"View-backed node not present in [parent displayNodeRecursiveDescription]");

  NSString *viewDescription = [parent.view valueForKey:@"recursiveDescription"];

  // Make sure string contains a, b, and c's pointer string
  XCTAssertTrue(stringContainsPointer(viewDescription, a), @"Layer backed node not present");
  XCTAssertTrue(stringContainsPointer(viewDescription, b), @"Layer-backed node not present");
  XCTAssertTrue(stringContainsPointer(viewDescription, c), @"View-backed node not present");

  // Make sure layer names have display node in description
  XCTAssertTrue(stringContainsPointer([a.layer debugDescription], a), @"Layer backed node not present");
  XCTAssertTrue(stringContainsPointer([b.layer debugDescription], b), @"Layer-backed node not present");

  [parent release];
}

- (void)checkNameInDescriptionIsLayerBacked:(BOOL)isLayerBacked
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.layerBacked = isLayerBacked;

  XCTAssertFalse([node.description rangeOfString:@"name"].location != NSNotFound, @"Shouldn't reference 'name' in description");
  node.name = @"big troll eater name";

  XCTAssertTrue([node.description rangeOfString:node.name].location != NSNotFound, @"Name didn't end up in description");
  XCTAssertTrue([node.description rangeOfString:@"name"].location != NSNotFound, @"Shouldn't reference 'name' in description");
  [node layer];
  XCTAssertTrue([node.description rangeOfString:node.name].location != NSNotFound, @"Name didn't end up in description");
  XCTAssertTrue([node.description rangeOfString:@"name"].location != NSNotFound, @"Shouldn't reference 'name' in description");

  [node release];
}

- (void)testNameInDescriptionLayer
{
  [self checkNameInDescriptionIsLayerBacked:YES];
}

- (void)testNameInDescriptionView
{
  [self checkNameInDescriptionIsLayerBacked:NO];
}


@end
