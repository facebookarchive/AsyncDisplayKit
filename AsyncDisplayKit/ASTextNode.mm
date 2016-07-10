//
//  ASTextNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextNode.h"
#import "ASTextNode+Beta.h"

#include <mutex>

#import "_ASDisplayLayer.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeInternal.h"
#import "ASHighlightOverlayLayer.h"
#import "ASDisplayNodeExtras.h"

#import "ASTextKitCoreTextAdditions.h"
#import "ASTextKitRenderer+Positioning.h"
#import "ASTextKitShadower.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

static const NSTimeInterval ASTextNodeHighlightFadeOutDuration = 0.15;
static const NSTimeInterval ASTextNodeHighlightFadeInDuration = 0.1;
static const CGFloat ASTextNodeHighlightLightOpacity = 0.11;
static const CGFloat ASTextNodeHighlightDarkOpacity = 0.22;
static NSString *ASTextNodeTruncationTokenAttributeName = @"ASTextNodeTruncationAttribute";

struct ASTextNodeDrawParameter {
  CGRect bounds;
  UIColor *backgroundColor;
};

@interface ASTextNode () <UIGestureRecognizerDelegate, NSLayoutManagerDelegate>

@end

@implementation ASTextNode {
  CGSize _shadowOffset;
  CGColorRef _shadowColor;
  CGFloat _shadowOpacity;
  CGFloat _shadowRadius;

  NSArray *_exclusionPaths;

  NSAttributedString *_composedTruncationText;

  NSString *_highlightedLinkAttributeName;
  id _highlightedLinkAttributeValue;
  ASTextNodeHighlightStyle _highlightStyle;
  NSRange _highlightRange;
  ASHighlightOverlayLayer *_activeHighlightLayer;

  CGSize _constrainedSize;

  ASTextKitRenderer *_renderer;

  ASTextNodeDrawParameter _drawParameter;

  UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@dynamic placeholderEnabled;

#pragma mark - NSObject

+ (void)initialize
{
  [super initialize];
  
  if (self != [ASTextNode class]) {
    // Prevent custom drawing in subclasses
    ASDisplayNodeAssert(!ASSubclassOverridesClassSelector([ASTextNode class], self, @selector(drawRect:withParameters:isCancelled:isRasterizing:)), @"Subclass %@ must not override drawRect:withParameters:isCancelled:isRasterizing: method. Custom drawing in %@ subclass is not supported.", NSStringFromClass(self), NSStringFromClass([ASTextNode class]));
  }
}

static NSArray *DefaultLinkAttributeNames = @[ NSLinkAttributeName ];

- (instancetype)init
{
  if (self = [super init]) {
    // Load default values from superclass.
    _shadowOffset = [super shadowOffset];
    CGColorRef superColor = [super shadowColor];
    if (superColor != NULL) {
      _shadowColor = CGColorRetain(superColor);
    }
    _shadowOpacity = [super shadowOpacity];
    _shadowRadius = [super shadowRadius];

    // Disable user interaction for text node by default.
    self.userInteractionEnabled = NO;
    self.needsDisplayOnBoundsChange = YES;

    _truncationMode = NSLineBreakByWordWrapping;
    _composedTruncationText = DefaultTruncationAttributedString();

    // The common case is for a text node to be non-opaque and blended over some background.
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];

    self.linkAttributeNames = DefaultLinkAttributeNames;

    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;

    _constrainedSize = CGSizeMake(-INFINITY, -INFINITY);

    // Placeholders
    // Disabled by default in ASDisplayNode, but add a few options for those who toggle
    // on the special placeholder behavior of ASTextNode.
    _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();
    _placeholderInsets = UIEdgeInsetsMake(1.0, 0.0, 1.0, 0.0);
  }

  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)dealloc
{
  if (_shadowColor != NULL) {
    CGColorRelease(_shadowColor);
  }
  
  [self _invalidateRenderer];

  if (_longPressGestureRecognizer) {
    _longPressGestureRecognizer.delegate = nil;
    [_longPressGestureRecognizer removeTarget:nil action:NULL];
    [self.view removeGestureRecognizer:_longPressGestureRecognizer];
  }
}

- (NSString *)description
{
  ASDN::MutexLocker l(_propertyLock);
  
  NSString *plainString = [[_attributedText string] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  NSString *truncationString = [_composedTruncationText string];
  if (plainString.length > 50)
    plainString = [[plainString substringToIndex:50] stringByAppendingString:@"\u2026"];
  return [NSString stringWithFormat:@"<%@: %p; text = \"%@\"; truncation string = \"%@\"; frame = %@; renderer = %p>", self.class, self, plainString, truncationString, self.nodeLoaded ? NSStringFromCGRect(self.layer.frame) : nil, _renderer];
}

#pragma mark - ASDisplayNode

// FIXME: Re-evaluate if it is still the right decision to clear the renderer at this stage.
// This code was written before TextKit and when 512MB devices were still the overwhelming majority.
- (void)displayDidFinish
{
  [super displayDidFinish];

  // We invalidate our renderer here to clear the very high memory cost of
  // keeping this around.  _invalidateRenderer will dealloc this onto a bg
  // thread resulting in less stutters on the main thread than if it were
  // to be deallocated in dealloc.  This is also helpful in opportunistically
  // reducing memory consumption and reducing the overall footprint of the app.
  [self _invalidateRenderer];
}

- (void)clearContents
{
  // We discard the backing store and renderer to prevent the very large
  // memory overhead of maintaining these for all text nodes.  They can be
  // regenerated when layout is necessary.
  [super clearContents];      // ASDisplayNode will set layer.contents = nil
  [self _invalidateRenderer];
}

- (void)didLoad
{
  [super didLoad];
  
  // If we are view-backed and the delegate cares, support the long-press callback.
  SEL longPressCallback = @selector(textNode:longPressedLinkAttribute:value:atPoint:textRange:);
  if (!self.isLayerBacked && [_delegate respondsToSelector:longPressCallback]) {
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPress:)];
    _longPressGestureRecognizer.cancelsTouchesInView = self.longPressCancelsTouches;
    _longPressGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_longPressGestureRecognizer];
  }
}

- (void)setFrame:(CGRect)frame
{
  [super setFrame:frame];
  [self _invalidateRendererIfNeededForBoundsSize:frame.size];
}

- (void)setBounds:(CGRect)bounds
{
  [super setBounds:bounds];
  [self _invalidateRendererIfNeededForBoundsSize:bounds.size];
}

#pragma mark - Renderer Management

- (ASTextKitRenderer *)_renderer
{
  return [self _rendererWithBounds:self.threadSafeBounds];
}

- (ASTextKitRenderer *)_rendererWithBounds:(CGRect)bounds
{
  ASDN::MutexLocker l(_propertyLock);

  if (_renderer == nil) {
    CGSize constrainedSize = _constrainedSize.width != -INFINITY ? _constrainedSize : bounds.size;
    _renderer = [[ASTextKitRenderer alloc] initWithTextKitAttributes:[self _rendererAttributes]
                                                     constrainedSize:constrainedSize];
  }
  return _renderer;
}

- (ASTextKitAttributes)_rendererAttributes
{
  ASDN::MutexLocker l(_propertyLock);
  
  return {
    .attributedString = _attributedText,
    .truncationAttributedString = _composedTruncationText,
    .lineBreakMode = _truncationMode,
    .maximumNumberOfLines = _maximumNumberOfLines,
    .exclusionPaths = _exclusionPaths,
    .pointSizeScaleFactors = _pointSizeScaleFactors,
    .layoutManagerCreationBlock = self.layoutManagerCreationBlock,
    .textStorageCreationBlock = self.textStorageCreationBlock,
  };
}

- (void)_invalidateRendererIfNeeded
{
  [self _invalidateRendererIfNeededForBoundsSize:self.threadSafeBounds.size];
}

- (void)_invalidateRendererIfNeededForBoundsSize:(CGSize)boundsSize
{
  if ([self _needInvalidateRendererForBoundsSize:boundsSize]) {
    // Our bounds have changed to a size that is not identical to our constraining size,
    // so our previous layout information is invalid, and TextKit may draw at the
    // incorrect origin.
    {
      ASDN::MutexLocker l(_propertyLock);
      _constrainedSize = CGSizeMake(-INFINITY, -INFINITY);
    }
    [self _invalidateRenderer];
  }
}

- (void)_invalidateRenderer
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_renderer) {
    // Destruction of the layout managers/containers/text storage is quite
    // expensive, and can take some time, so we dispatch onto a bg queue to
    // actually dealloc.
    __block ASTextKitRenderer *renderer = _renderer;
    
    ASPerformBlockOnDeallocationQueue(^{
      renderer = nil;
    });
    _renderer = nil;
  }
}

#pragma mark - Layout and Sizing

- (BOOL)_needInvalidateRendererForBoundsSize:(CGSize)boundsSize
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_renderer == nil) {
    return YES;
  }
  
  // If the size is not the same as the constraint we provided to the renderer, start out assuming we need
  // a new one.  However, there are common cases where the constrained size doesn't need to be the same as calculated.
  CGSize rendererConstrainedSize = _renderer.constrainedSize;
  
  if (CGSizeEqualToSize(boundsSize, rendererConstrainedSize)) {
    return NO;
  } else {
    // It is very common to have a constrainedSize with a concrete, specific width but +Inf height.
    // In this case, as long as the text node has bounds as large as the full calculatedLayout suggests,
    // it means that the text has all the room it needs (as it was not vertically bounded).  So, we will not
    // experience truncation and don't need to recreate the renderer with the size it already calculated,
    // as this would essentially serve to set its constrainedSize to be its calculatedSize (unnecessary).
    ASLayout *layout = self.calculatedLayout;
    if (layout != nil && CGSizeEqualToSize(boundsSize, layout.size)) {
      if (boundsSize.width != rendererConstrainedSize.width) {
        // Don't bother changing _constrainedSize, as ASDisplayNode's -measure: method would have a cache miss
        // and ask us to recalculate layout if it were called with the same calculatedSize that got us to this point!
        _renderer.constrainedSize = boundsSize;
      }
      return NO;
    } else {
      return YES;
    }
  }
}

- (void)calculatedLayoutDidChange
{
  [super calculatedLayoutDidChange];
  
  ASLayout *layout = self.calculatedLayout;
  
  if (layout != nil) {
    ASDN::MutexLocker l(_propertyLock);
    _constrainedSize = layout.size;
    _renderer.constrainedSize = layout.size;
  }
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDisplayNodeAssert(constrainedSize.width >= 0, @"Constrained width for text (%f) is too  narrow", constrainedSize.width);
  ASDisplayNodeAssert(constrainedSize.height >= 0, @"Constrained height for text (%f) is too short", constrainedSize.height);
  
  ASDN::MutexLocker l(_propertyLock);
  
  _constrainedSize = constrainedSize;
  
  // Instead of invalidating the renderer, in case this is a new call with a different constrained size,
  // just update the size of the NSTextContainer that is owned by the renderer's internal context object.
  [self _renderer].constrainedSize = _constrainedSize;

  [self setNeedsDisplay];
  
  CGSize size = [self _renderer].size;
  if (_attributedText.length > 0) {
    CGFloat screenScale = ASScreenScale();
    self.ascender = round([[_attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * screenScale)/screenScale;
    self.descender = round([[_attributedText attribute:NSFontAttributeName atIndex:_attributedText.length - 1 effectiveRange:NULL] descender] * screenScale)/screenScale;
    if (_renderer.currentScaleFactor > 0 && _renderer.currentScaleFactor < 1.0) {
      // while not perfect, this is a good estimate of what the ascender of the scaled font will be.
      self.ascender *= _renderer.currentScaleFactor;
      self.descender *= _renderer.currentScaleFactor;
    }
  }
  return size;
}

#pragma mark - Modifying User Text

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  
  if (attributedText == nil) {
    attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:nil];
  }
  
  // Don't hold textLock for too long.
  {
    ASDN::MutexLocker l(_propertyLock);
    if (ASObjectIsEqual(attributedText, _attributedText)) {
      return;
    }

    _attributedText = ASCleanseAttributedStringOfCoreTextAttributes(attributedText);
    
    // Sync the truncation string with attributes from the updated _attributedString
    // Without this, the size calculation of the text with truncation applied will
    // not take into account the attributes of attributedText in the last line
    [self _updateComposedTruncationText];
    
    // We need an entirely new renderer
    [self _invalidateRenderer];
  }
  
  NSUInteger length = attributedText.length;
  if (length > 0) {
    CGFloat screenScale = ASScreenScale();
    self.ascender = round([[attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * screenScale)/screenScale;
    self.descender = round([[attributedText attribute:NSFontAttributeName atIndex:length - 1 effectiveRange:NULL] descender] * screenScale)/screenScale;
  }

  // Tell the display node superclasses that the cached layout is incorrect now
  [self invalidateCalculatedLayout];

  [self setNeedsDisplay];
  
  
  // Accessiblity
  self.accessibilityLabel = attributedText.string;
  self.isAccessibilityElement = (length != 0); // We're an accessibility element by default if there is a string.
}

#pragma mark - Text Layout

- (void)setExclusionPaths:(NSArray *)exclusionPaths
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (ASObjectIsEqual(exclusionPaths, _exclusionPaths)) {
    return;
  }
  
  _exclusionPaths = [exclusionPaths copy];
  [self _invalidateRenderer];
  [self invalidateCalculatedLayout];
  [self setNeedsDisplay];
}

- (NSArray *)exclusionPaths
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _exclusionPaths;
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  ASDN::MutexLocker l(_propertyLock);
  
  _drawParameter = {
    .backgroundColor = self.backgroundColor,
    .bounds = self.bounds
  };
  return nil;
}


- (void)drawRect:(CGRect)bounds withParameters:(id <NSObject>)p isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;
{
  ASDN::MutexLocker l(_propertyLock);

  ASTextNodeDrawParameter drawParameter = _drawParameter;
  CGRect drawParameterBounds = drawParameter.bounds;
  UIColor *backgroundColor = isRasterizing ? nil : drawParameter.backgroundColor;
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  ASDisplayNodeAssert(context, @"This is no good without a context.");
  
  CGContextSaveGState(context);
  
  ASTextKitRenderer *renderer = [self _rendererWithBounds:drawParameterBounds];
  UIEdgeInsets shadowPadding = [self shadowPaddingWithRenderer:renderer];
  CGPoint boundsOrigin = drawParameterBounds.origin;
  CGPoint textOrigin = CGPointMake(boundsOrigin.x - shadowPadding.left, boundsOrigin.y - shadowPadding.top);
  
  // Fill background
  if (backgroundColor != nil) {
    [backgroundColor setFill];
    UIRectFillUsingBlendMode(CGContextGetClipBoundingBox(context), kCGBlendModeCopy);
  }
  
  // Draw shadow
  [renderer.shadower setShadowInContext:context];
  
  // Draw text
  bounds.origin = textOrigin;
  [renderer drawInContext:context bounds:bounds];
  
  CGContextRestoreGState(context);
}

#pragma mark - Attributes

- (id)linkAttributeValueAtPoint:(CGPoint)point
                  attributeName:(out NSString **)attributeNameOut
                          range:(out NSRange *)rangeOut
{
  return [self _linkAttributeValueAtPoint:point
                            attributeName:attributeNameOut
                                    range:rangeOut
            inAdditionalTruncationMessage:NULL
                          forHighlighting:NO];
}

- (id)_linkAttributeValueAtPoint:(CGPoint)point
                   attributeName:(out NSString **)attributeNameOut
                           range:(out NSRange *)rangeOut
   inAdditionalTruncationMessage:(out BOOL *)inAdditionalTruncationMessageOut
                 forHighlighting:(BOOL)highlighting
{
  ASDisplayNodeAssertMainThread();
  
  ASDN::MutexLocker l(_propertyLock);
  
  ASTextKitRenderer *renderer = [self _renderer];
  NSRange visibleRange = renderer.firstVisibleRange;
  NSAttributedString *attributedString = _attributedText;
  NSRange clampedRange = NSIntersectionRange(visibleRange, NSMakeRange(0, attributedString.length));

  // Check in a 9-point region around the actual touch point so we make sure
  // we get the best attribute for the touch.
  __block CGFloat minimumGlyphDistance = CGFLOAT_MAX;

  // Final output vars
  __block id linkAttributeValue = nil;
  __block BOOL inTruncationMessage = NO;

  [renderer enumerateTextIndexesAtPosition:point usingBlock:^(NSUInteger characterIndex, CGRect glyphBoundingRect, BOOL *stop) {
    CGPoint glyphLocation = CGPointMake(CGRectGetMidX(glyphBoundingRect), CGRectGetMidY(glyphBoundingRect));
    CGFloat currentDistance = sqrtf(powf(point.x - glyphLocation.x, 2.f) + powf(point.y - glyphLocation.y, 2.f));
    if (currentDistance >= minimumGlyphDistance) {
      // If the distance computed from the touch to the glyph location is
      // not the minimum among the located link attributes, we can just skip
      // to the next location.
      return;
    }

    // Check if it's outside the visible range, if so, then we mark this touch
    // as inside the truncation message, because in at least one of the touch
    // points it was.
    if (!(NSLocationInRange(characterIndex, visibleRange))) {
      inTruncationMessage = YES;
    }

    if (inAdditionalTruncationMessageOut != NULL) {
      *inAdditionalTruncationMessageOut = inTruncationMessage;
    }

    // Short circuit here if it's just in the truncation message.  Since the
    // truncation message may be beyond the scope of the actual input string,
    // we have to make sure that we don't start asking for attributes on it.
    if (inTruncationMessage) {
      return;
    }

    for (NSString *attributeName in _linkAttributeNames) {
      NSRange range;
      id value = [attributedString attribute:attributeName atIndex:characterIndex longestEffectiveRange:&range inRange:clampedRange];
      NSString *name = attributeName;

      if (value == nil || name == nil) {
        // Didn't find anything
        continue;
      }

      // If highlighting, check with delegate first. If not implemented, assume YES.
      if (highlighting
          && [_delegate respondsToSelector:@selector(textNode:shouldHighlightLinkAttribute:value:atPoint:)]
          && ![_delegate textNode:self shouldHighlightLinkAttribute:name value:value atPoint:point]) {
        value = nil;
        name = nil;
      }

      if (value != nil || name != nil) {
        // We found a minimum glyph distance link attribute, so set the min
        // distance, and the out params.
        minimumGlyphDistance = currentDistance;

        if (rangeOut != NULL && value != nil) {
          *rangeOut = range;
          // Limit to only the visible range, because the attributed string will
          // return values outside the visible range.
          if (NSMaxRange(*rangeOut) > NSMaxRange(visibleRange)) {
            (*rangeOut).length = MAX(NSMaxRange(visibleRange) - (*rangeOut).location, 0);
          }
        }

        if (attributeNameOut != NULL) {
          *attributeNameOut = name;
        }

        // Set the values for the next iteration
        linkAttributeValue = value;

        break;
      }
    }
  }];

  return linkAttributeValue;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  ASDisplayNodeAssertMainThread();
  
  if (gestureRecognizer == _longPressGestureRecognizer) {
    // Don't allow long press on truncation message
    if ([self _pendingTruncationTap]) {
      return NO;
    }

    // Ask our delegate if a long-press on an attribute is relevant
    if ([_delegate respondsToSelector:@selector(textNode:shouldLongPressLinkAttribute:value:atPoint:)]) {
      return [_delegate textNode:self
        shouldLongPressLinkAttribute:_highlightedLinkAttributeName
                               value:_highlightedLinkAttributeValue
                             atPoint:[gestureRecognizer locationInView:self.view]];
    }

    // Otherwise we are good to go.
    return YES;
  }

  if (([self _pendingLinkTap] || [self _pendingTruncationTap])
      && [gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]
      && CGRectContainsPoint(self.threadSafeBounds, [gestureRecognizer locationInView:self.view])) {
    return NO;
  }

  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

#pragma mark - Highlighting

- (ASTextNodeHighlightStyle)highlightStyle
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _highlightStyle;
}

- (void)setHighlightStyle:(ASTextNodeHighlightStyle)highlightStyle
{
  ASDN::MutexLocker l(_propertyLock);
  
  _highlightStyle = highlightStyle;
}

- (NSRange)highlightRange
{
  ASDisplayNodeAssertMainThread();
  
  return _highlightRange;
}

- (void)setHighlightRange:(NSRange)highlightRange
{
  [self setHighlightRange:highlightRange animated:NO];
}

- (void)setHighlightRange:(NSRange)highlightRange animated:(BOOL)animated
{
  [self _setHighlightRange:highlightRange forAttributeName:nil value:nil animated:animated];
}

- (void)_setHighlightRange:(NSRange)highlightRange forAttributeName:(NSString *)highlightedAttributeName value:(id)highlightedAttributeValue animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();

  _highlightedLinkAttributeName = highlightedAttributeName;
  _highlightedLinkAttributeValue = highlightedAttributeValue;

  if (!NSEqualRanges(highlightRange, _highlightRange) && ((0 != highlightRange.length) || (0 != _highlightRange.length))) {

    _highlightRange = highlightRange;

    if (_activeHighlightLayer) {
      if (animated) {
        __weak CALayer *weakHighlightLayer = _activeHighlightLayer;
        _activeHighlightLayer = nil;

        weakHighlightLayer.opacity = 0.0;

        CFTimeInterval beginTime = CACurrentMediaTime();
        CABasicAnimation *possibleFadeIn = (CABasicAnimation *)[weakHighlightLayer animationForKey:@"opacity"];
        if (possibleFadeIn) {
          // Calculate when we should begin fading out based on the end of the fade in animation,
          // Also check to make sure that the new begin time hasn't already passed
          CGFloat newBeginTime = (possibleFadeIn.beginTime + possibleFadeIn.duration);
          if (newBeginTime > beginTime) {
            beginTime = newBeginTime;
          }
        }
        
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeOut.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fadeOut.fromValue = possibleFadeIn.toValue ? : @(((CALayer *)weakHighlightLayer.presentationLayer).opacity);
        fadeOut.toValue = @0.0;
        fadeOut.fillMode = kCAFillModeBoth;
        fadeOut.duration = ASTextNodeHighlightFadeOutDuration;
        fadeOut.beginTime = beginTime;

        dispatch_block_t prev = [CATransaction completionBlock];
        [CATransaction setCompletionBlock:^{
          [weakHighlightLayer removeFromSuperlayer];
        }];

        [weakHighlightLayer addAnimation:fadeOut forKey:fadeOut.keyPath];

        [CATransaction setCompletionBlock:prev];

      } else {
        [_activeHighlightLayer removeFromSuperlayer];
        _activeHighlightLayer = nil;
      }
    }
    if (0 != highlightRange.length) {
      // Find layer in hierarchy that allows us to draw highlighting on.
      CALayer *highlightTargetLayer = self.layer;
      while (highlightTargetLayer != nil) {
        if (highlightTargetLayer.as_allowsHighlightDrawing) {
          break;
        }
        highlightTargetLayer = highlightTargetLayer.superlayer;
      }

      if (highlightTargetLayer != nil) {
        ASDN::MutexLocker l(_propertyLock);

        NSArray *highlightRects = [[self _renderer] rectsForTextRange:highlightRange measureOption:ASTextKitRendererMeasureOptionBlock];
        NSMutableArray *converted = [NSMutableArray arrayWithCapacity:highlightRects.count];
        for (NSValue *rectValue in highlightRects) {
          UIEdgeInsets shadowPadding = _renderer.shadower.shadowPadding;
          CGRect rendererRect = ASTextNodeAdjustRenderRectForShadowPadding(rectValue.CGRectValue, shadowPadding);
          CGRect highlightedRect = [self.layer convertRect:rendererRect toLayer:highlightTargetLayer];

          // We set our overlay layer's frame to the bounds of the highlight target layer.
          // Offset highlight rects to avoid double-counting target layer's bounds.origin.
          highlightedRect.origin.x -= highlightTargetLayer.bounds.origin.x;
          highlightedRect.origin.y -= highlightTargetLayer.bounds.origin.y;
          [converted addObject:[NSValue valueWithCGRect:highlightedRect]];
        }

        ASHighlightOverlayLayer *overlayLayer = [[ASHighlightOverlayLayer alloc] initWithRects:converted];
        overlayLayer.highlightColor = [[self class] _highlightColorForStyle:self.highlightStyle];
        overlayLayer.frame = highlightTargetLayer.bounds;
        overlayLayer.masksToBounds = NO;
        overlayLayer.opacity = [[self class] _highlightOpacityForStyle:self.highlightStyle];
        [highlightTargetLayer addSublayer:overlayLayer];

        if (animated) {
          CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
          fadeIn.fromValue = @0.0;
          fadeIn.toValue = @(overlayLayer.opacity);
          fadeIn.duration = ASTextNodeHighlightFadeInDuration;
          fadeIn.beginTime = CACurrentMediaTime();

          [overlayLayer addAnimation:fadeIn forKey:fadeIn.keyPath];
        }

        [overlayLayer setNeedsDisplay];

        _activeHighlightLayer = overlayLayer;
      }
    }
  }
}

- (void)_clearHighlightIfNecessary
{
  ASDisplayNodeAssertMainThread();
  
  if ([self _pendingLinkTap] || [self _pendingTruncationTap]) {
    [self setHighlightRange:NSMakeRange(0, 0) animated:YES];
  }
}

+ (CGColorRef)_highlightColorForStyle:(ASTextNodeHighlightStyle)style
{
  return [UIColor colorWithWhite:(style == ASTextNodeHighlightStyleLight ? 0.0 : 1.0) alpha:1.0].CGColor;
}

+ (CGFloat)_highlightOpacityForStyle:(ASTextNodeHighlightStyle)style
{
  return (style == ASTextNodeHighlightStyleLight) ? ASTextNodeHighlightLightOpacity : ASTextNodeHighlightDarkOpacity;
}

#pragma mark - Text rects

static CGRect ASTextNodeAdjustRenderRectForShadowPadding(CGRect rendererRect, UIEdgeInsets shadowPadding) {
  rendererRect.origin.x -= shadowPadding.left;
  rendererRect.origin.y -= shadowPadding.top;
  return rendererRect;
}

- (NSArray *)rectsForTextRange:(NSRange)textRange
{
  return [self _rectsForTextRange:textRange measureOption:ASTextKitRendererMeasureOptionCapHeight];
}

- (NSArray *)highlightRectsForTextRange:(NSRange)textRange
{
  return [self _rectsForTextRange:textRange measureOption:ASTextKitRendererMeasureOptionBlock];
}

- (NSArray *)_rectsForTextRange:(NSRange)textRange measureOption:(ASTextKitRendererMeasureOption)measureOption
{
  ASDN::MutexLocker l(_propertyLock);
  
  NSArray *rects = [[self _renderer] rectsForTextRange:textRange measureOption:measureOption];
  NSMutableArray *adjustedRects = [NSMutableArray array];

  for (NSValue *rectValue in rects) {
    CGRect rect = [rectValue CGRectValue];
    rect = ASTextNodeAdjustRenderRectForShadowPadding(rect, self.shadowPadding);

    NSValue *adjustedRectValue = [NSValue valueWithCGRect:rect];
    [adjustedRects addObject:adjustedRectValue];
  }

  return adjustedRects;
}

- (CGRect)trailingRect
{
  ASDN::MutexLocker l(_propertyLock);
  
  CGRect rect = [[self _renderer] trailingRect];
  return ASTextNodeAdjustRenderRectForShadowPadding(rect, self.shadowPadding);
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  ASDN::MutexLocker l(_propertyLock);
  
  CGRect frame = [[self _renderer] frameForTextRange:textRange];
  return ASTextNodeAdjustRenderRectForShadowPadding(frame, self.shadowPadding);
}

#pragma mark - Placeholders

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  ASDN::MutexLocker l(_propertyLock);
  
  _placeholderColor = placeholderColor;

  // prevent placeholders if we don't have a color
  self.placeholderEnabled = placeholderColor != nil;
}

- (UIImage *)placeholderImage
{
  // FIXME: Replace this implementation with reusable CALayers that have .backgroundColor set.
  // This would completely eliminate the memory and performance cost of the backing store.
  CGSize size = self.calculatedSize;
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    return nil;
  }
  
  ASDN::MutexLocker l(_propertyLock);
  
  UIGraphicsBeginImageContext(size);
  [self.placeholderColor setFill];

  ASTextKitRenderer *renderer = [self _renderer];
  NSRange visibleRange = renderer.firstVisibleRange;

  // cap height is both faster and creates less subpixel blending
  NSArray *lineRects = [self _rectsForTextRange:visibleRange measureOption:ASTextKitRendererMeasureOptionLineHeight];

  // fill each line with the placeholder color
  for (NSValue *rectValue in lineRects) {
    CGRect lineRect = [rectValue CGRectValue];
    CGRect fillBounds = CGRectIntegral(UIEdgeInsetsInsetRect(lineRect, self.placeholderInsets));

    if (fillBounds.size.width > 0.0 && fillBounds.size.height > 0.0) {
      UIRectFill(fillBounds);
    }
  }

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

#pragma mark - Touch Handling

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  
  if (!_passthroughNonlinkTouches) {
    return [super pointInside:point withEvent:event];
  }

  NSRange range = NSMakeRange(0, 0);
  NSString *linkAttributeName = nil;
  BOOL inAdditionalTruncationMessage = NO;

  id linkAttributeValue = [self _linkAttributeValueAtPoint:point
                                             attributeName:&linkAttributeName
                                                     range:&range
                             inAdditionalTruncationMessage:&inAdditionalTruncationMessage
                                           forHighlighting:YES];

  NSUInteger lastCharIndex = NSIntegerMax;
  BOOL linkCrossesVisibleRange = (lastCharIndex > range.location) && (lastCharIndex < NSMaxRange(range) - 1);

  if (inAdditionalTruncationMessage) {
    return YES;
  } else if (range.length && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
    return YES;
  } else {
    return NO;
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  
  [super touchesBegan:touches withEvent:event];

  CGPoint point = [[touches anyObject] locationInView:self.view];

  NSRange range = NSMakeRange(0, 0);
  NSString *linkAttributeName = nil;
  BOOL inAdditionalTruncationMessage = NO;

  id linkAttributeValue = [self _linkAttributeValueAtPoint:point
                                             attributeName:&linkAttributeName
                                                     range:&range
                             inAdditionalTruncationMessage:&inAdditionalTruncationMessage
                                           forHighlighting:YES];

  NSUInteger lastCharIndex = NSIntegerMax;
  BOOL linkCrossesVisibleRange = (lastCharIndex > range.location) && (lastCharIndex < NSMaxRange(range) - 1);

  if (inAdditionalTruncationMessage) {
    NSRange visibleRange = NSMakeRange(0, 0);
    {
      ASDN::MutexLocker l(_propertyLock);
      visibleRange = [self _renderer].firstVisibleRange;
    }
    NSRange truncationMessageRange = [self _additionalTruncationMessageRangeWithVisibleRange:visibleRange];
    [self _setHighlightRange:truncationMessageRange forAttributeName:ASTextNodeTruncationTokenAttributeName value:nil animated:YES];
  } else if (range.length && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
    [self _setHighlightRange:range forAttributeName:linkAttributeName value:linkAttributeValue animated:YES];
  }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesCancelled:touches withEvent:event];
  
  [self _clearHighlightIfNecessary];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesEnded:touches withEvent:event];
  
  if ([self _pendingLinkTap] && [_delegate respondsToSelector:@selector(textNode:tappedLinkAttribute:value:atPoint:textRange:)]) {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [_delegate textNode:self tappedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:point textRange:_highlightRange];
  }

  if ([self _pendingTruncationTap]) {
    if ([_delegate respondsToSelector:@selector(textNodeTappedTruncationToken:)]) {
      [_delegate textNodeTappedTruncationToken:self];
    }
  }

  [self _clearHighlightIfNecessary];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesMoved:touches withEvent:event];

  UITouch *touch = [touches anyObject];
  CGPoint locationInView = [touch locationInView:self.view];
  // on 3D Touch enabled phones, this gets fired with changes in force, and usually will get fired immediately after touchesBegan:withEvent:
  if (CGPointEqualToPoint([touch previousLocationInView:self.view], locationInView))
    return;
  
  // If touch has moved out of the current highlight range, clear the highlight.
  if (_highlightRange.length > 0) {
    NSRange range = NSMakeRange(0, 0);
    [self _linkAttributeValueAtPoint:locationInView
                       attributeName:NULL
                               range:&range
       inAdditionalTruncationMessage:NULL
                     forHighlighting:YES];

    if (!NSEqualRanges(_highlightRange, range)) {
      [self _clearHighlightIfNecessary];
    }
  }
}

- (void)_handleLongPress:(UILongPressGestureRecognizer *)longPressRecognizer
{
  ASDisplayNodeAssertMainThread();
  
  // Respond to long-press when it begins, not when it ends.
  if (longPressRecognizer.state == UIGestureRecognizerStateBegan) {
    if ([_delegate respondsToSelector:@selector(textNode:longPressedLinkAttribute:value:atPoint:textRange:)]) {
      CGPoint touchPoint = [_longPressGestureRecognizer locationInView:self.view];
      [_delegate textNode:self longPressedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:touchPoint textRange:_highlightRange];
    }
  }
}

- (BOOL)_pendingLinkTap
{
  ASDN::MutexLocker l(_propertyLock);
  
  return (_highlightedLinkAttributeValue != nil && ![self _pendingTruncationTap]) && _delegate != nil;
}

- (BOOL)_pendingTruncationTap
{
  ASDN::MutexLocker l(_propertyLock);
  
  return [_highlightedLinkAttributeName isEqualToString:ASTextNodeTruncationTokenAttributeName];
}

#pragma mark - Shadow Properties

- (CGColorRef)shadowColor
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _shadowColor;
}

- (void)setShadowColor:(CGColorRef)shadowColor
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_shadowColor != shadowColor) {
    if (shadowColor != NULL) {
      CGColorRetain(shadowColor);
    }
    _shadowColor = shadowColor;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (CGSize)shadowOffset
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (!CGSizeEqualToSize(_shadowOffset, shadowOffset)) {
    _shadowOffset = shadowOffset;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (CGFloat)shadowOpacity
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _shadowOpacity;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_shadowOpacity != shadowOpacity) {
    _shadowOpacity = shadowOpacity;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (CGFloat)shadowRadius
{
  ASDN::MutexLocker l(_propertyLock);
  
  return _shadowRadius;
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_shadowRadius != shadowRadius) {
    _shadowRadius = shadowRadius;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (UIEdgeInsets)shadowPadding
{
  return [self shadowPaddingWithRenderer:[self _renderer]];
}

- (UIEdgeInsets)shadowPaddingWithRenderer:(ASTextKitRenderer *)renderer
{
  ASDN::MutexLocker l(_propertyLock);
  
  return renderer.shadower.shadowPadding;
}

#pragma mark - Truncation Message

static NSAttributedString *DefaultTruncationAttributedString()
{
  static NSAttributedString *defaultTruncationAttributedString;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultTruncationAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"\u2026", @"Default truncation string")];
  });
  return defaultTruncationAttributedString;
}

- (void)setTruncationAttributedText:(NSAttributedString *)truncationAttributedText
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (ASObjectIsEqual(_truncationAttributedText, truncationAttributedText)) {
    return;
  }

  _truncationAttributedText = [truncationAttributedText copy];
  [self _invalidateTruncationText];
}

- (void)setAdditionalTruncationMessage:(NSAttributedString *)additionalTruncationMessage
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (ASObjectIsEqual(_additionalTruncationMessage, additionalTruncationMessage)) {
    return;
  }

  _additionalTruncationMessage = [additionalTruncationMessage copy];
  [self _invalidateTruncationText];
}

- (void)setTruncationMode:(NSLineBreakMode)truncationMode
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_truncationMode != truncationMode) {
    _truncationMode = truncationMode;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (BOOL)isTruncated
{
  ASDN::MutexLocker l(_propertyLock);
  
  ASTextKitRenderer *renderer = [self _renderer];
  return renderer.firstVisibleRange.length < _attributedText.length;
}

- (void)setPointSizeScaleFactors:(NSArray *)pointSizeScaleFactors
{
  ASDN::MutexLocker l(_propertyLock);
  
  if ([_pointSizeScaleFactors isEqualToArray:pointSizeScaleFactors] == NO) {
    _pointSizeScaleFactors = pointSizeScaleFactors;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }}

- (void)setMaximumNumberOfLines:(NSUInteger)maximumNumberOfLines
{
  ASDN::MutexLocker l(_propertyLock);
  
  if (_maximumNumberOfLines != maximumNumberOfLines) {
    _maximumNumberOfLines = maximumNumberOfLines;
    [self _invalidateRenderer];
    [self setNeedsDisplay];
  }
}

- (NSUInteger)lineCount
{
  ASDN::MutexLocker l(_propertyLock);
  
  return [[self _renderer] lineCount];
}

#pragma mark - Truncation Message

- (void)_updateComposedTruncationText
{
  ASDN::MutexLocker l(_propertyLock);
  
  _composedTruncationText = [self _prepareTruncationStringForDrawing:[self _composedTruncationText]];
}

- (void)_invalidateTruncationText
{
  [self _updateComposedTruncationText];
  [self _invalidateRenderer];
  [self setNeedsDisplay];
}

/**
 * @return the additional truncation message range within the as-rendered text.
 * Must be called from main thread
 */
- (NSRange)_additionalTruncationMessageRangeWithVisibleRange:(NSRange)visibleRange
{
  ASDN::MutexLocker l(_propertyLock);
  
  // Check if we even have an additional truncation message.
  if (!_additionalTruncationMessage) {
    return NSMakeRange(NSNotFound, 0);
  }

  // Character location of the unicode ellipsis (the first index after the visible range)
  NSInteger truncationTokenIndex = NSMaxRange(visibleRange);

  NSUInteger additionalTruncationMessageLength = _additionalTruncationMessage.length;
  // We get the location of the truncation token, then add the length of the
  // truncation attributed string +1 for the space between.
  return NSMakeRange(truncationTokenIndex + _truncationAttributedText.length + 1, additionalTruncationMessageLength);
}

/**
 * @return the truncation message for the string.  If there are both an
 * additional truncation message and a truncation attributed string, they will
 * be properly composed.
 */
- (NSAttributedString *)_composedTruncationText
{
  ASDN::MutexLocker l(_propertyLock);
  
  //If we have neither return the default
  if (!_additionalTruncationMessage && !_truncationAttributedText) {
    return _composedTruncationText;
  }
  // Short circuit if we only have one or the other.
  if (!_additionalTruncationMessage) {
    return _truncationAttributedText;
  }
  if (!_truncationAttributedText) {
    return _additionalTruncationMessage;
  }

  // If we've reached this point, both _additionalTruncationMessage and
  // _truncationAttributedString are present.  Compose them.

  NSMutableAttributedString *newComposedTruncationString = [[NSMutableAttributedString alloc] initWithAttributedString:_truncationAttributedText];
  [newComposedTruncationString replaceCharactersInRange:NSMakeRange(newComposedTruncationString.length, 0) withString:@" "];
  [newComposedTruncationString appendAttributedString:_additionalTruncationMessage];
  return newComposedTruncationString;
}

/**
 * - cleanses it of core text attributes so TextKit doesn't crash
 * - Adds whole-string attributes so the truncation message matches the styling
 * of the body text
 */
- (NSAttributedString *)_prepareTruncationStringForDrawing:(NSAttributedString *)truncationString
{
  ASDN::MutexLocker l(_propertyLock);
  
  truncationString = ASCleanseAttributedStringOfCoreTextAttributes(truncationString);
  NSMutableAttributedString *truncationMutableString = [truncationString mutableCopy];
  // Grab the attributes from the full string
  if (_attributedText.length > 0) {
    NSAttributedString *originalString = _truncationAttributedText;
    NSInteger originalStringLength = _truncationAttributedText.length;
    // Add any of the original string's attributes to the truncation string,
    // but don't overwrite any of the truncation string's attributes
    NSDictionary *originalStringAttributes = [originalString attributesAtIndex:originalStringLength-1 effectiveRange:NULL];
    [truncationString enumerateAttributesInRange:NSMakeRange(0, truncationString.length) options:0 usingBlock:
     ^(NSDictionary *attributes, NSRange range, BOOL *stop) {
       NSMutableDictionary *futureTruncationAttributes = [NSMutableDictionary dictionaryWithDictionary:originalStringAttributes];
       [futureTruncationAttributes addEntriesFromDictionary:attributes];
       [truncationMutableString setAttributes:futureTruncationAttributes range:range];
     }];
  }
  return truncationMutableString;
}

@end

@implementation ASTextNode (Deprecated)

- (void)setAttributedString:(NSAttributedString *)attributedString
{
  self.attributedText = attributedString;
}

- (NSAttributedString *)attributedString
{
  return self.attributedText;
}

- (void)setTruncationAttributedString:(NSAttributedString *)truncationAttributedString
{
  self.truncationAttributedText = truncationAttributedString;
}

- (NSAttributedString *)truncationAttributedString
{
  return self.truncationAttributedText;
}

@end
