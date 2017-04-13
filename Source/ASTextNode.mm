//
//  ASTextNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASTextNode+Beta.h>

#include <mutex>
#import <tgmath.h>

#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASHighlightOverlayLayer.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>

#import <AsyncDisplayKit/ASTextKitCoreTextAdditions.h>
#import <AsyncDisplayKit/ASTextKitRenderer+Positioning.h>
#import <AsyncDisplayKit/ASTextKitShadower.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayout.h>

#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/ASEqualityHashHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

/**
 * If set, we will record all values set to attributedText into an array
 * and once we get 2000, we'll write them all out into a plist file.
 *
 * This is useful for gathering realistic text data sets from apps for performance
 * testing.
 */
#define AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS 0

static const NSTimeInterval ASTextNodeHighlightFadeOutDuration = 0.15;
static const NSTimeInterval ASTextNodeHighlightFadeInDuration = 0.1;
static const CGFloat ASTextNodeHighlightLightOpacity = 0.11;
static const CGFloat ASTextNodeHighlightDarkOpacity = 0.22;
static NSString *ASTextNodeTruncationTokenAttributeName = @"ASTextNodeTruncationAttribute";

struct ASTextNodeDrawParameter {
  CGRect bounds;
  UIColor *backgroundColor;
};

#pragma mark - ASTextKitRenderer

@interface ASTextNodeRendererKey : NSObject
@property (assign, nonatomic) ASTextKitAttributes attributes;
@property (assign, nonatomic) CGSize constrainedSize;
@end

@implementation ASTextNodeRendererKey

- (NSUInteger)hash
{
  return _attributes.hash() ^ ASHashFromCGSize(_constrainedSize);
}

- (BOOL)isEqual:(ASTextNodeRendererKey *)object
{
  if (self == object) {
    return YES;
  }
  
  return _attributes == object.attributes && CGSizeEqualToSize(_constrainedSize, object.constrainedSize);
}

@end

static NSCache *sharedRendererCache()
{ 
 static dispatch_once_t onceToken;
 static NSCache *__rendererCache = nil;
 dispatch_once(&onceToken, ^{
   __rendererCache = [[NSCache alloc] init];
   __rendererCache.countLimit = 500; // 500 renders cache
 });
 return __rendererCache;
}

/**
 The concept here is that neither the node nor layout should ever have a strong reference to the renderer object.
 This is to reduce memory load when loading thousands and thousands of text nodes into memory at once. Instead
 we maintain a LRU renderer cache that is queried via a unique key based on text kit attributes and constrained size. 
 */

static ASTextKitRenderer *rendererForAttributes(ASTextKitAttributes attributes, CGSize constrainedSize)
{
  NSCache *cache = sharedRendererCache();
  
  ASTextNodeRendererKey *key = [[ASTextNodeRendererKey alloc] init];
  key.attributes = attributes;
  key.constrainedSize = constrainedSize;

  ASTextKitRenderer *renderer = [cache objectForKey:key];
  if (renderer == nil) {
    renderer = [[ASTextKitRenderer alloc] initWithTextKitAttributes:attributes constrainedSize:constrainedSize];
    [cache setObject:renderer forKey:key];
  }
  
  return renderer;
}

@interface ASTextNode () <UIGestureRecognizerDelegate>

@end

@implementation ASTextNode {
  CGSize _shadowOffset;
  CGColorRef _shadowColor;
  UIColor *_cachedShadowUIColor;
  CGFloat _shadowOpacity;
  CGFloat _shadowRadius;
  
  UIEdgeInsets _textContainerInset;

  NSArray *_exclusionPaths;

  NSAttributedString *_attributedText;
  NSAttributedString *_composedTruncationText;

  NSString *_highlightedLinkAttributeName;
  id _highlightedLinkAttributeValue;
  ASTextNodeHighlightStyle _highlightStyle;
  NSRange _highlightRange;
  ASHighlightOverlayLayer *_activeHighlightLayer;

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
    _shadowColor = CGColorRetain([super shadowColor]);
    _shadowOpacity = [super shadowOpacity];
    _shadowRadius = [super shadowRadius];

    // Disable user interaction for text node by default.
    self.userInteractionEnabled = NO;
    self.needsDisplayOnBoundsChange = YES;

    _truncationMode = NSLineBreakByWordWrapping;

    // The common case is for a text node to be non-opaque and blended over some background.
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];

    self.linkAttributeNames = DefaultLinkAttributeNames;

    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;

    // Placeholders
    // Disabled by default in ASDisplayNode, but add a few options for those who toggle
    // on the special placeholder behavior of ASTextNode.
    _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();
    _placeholderInsets = UIEdgeInsetsMake(1.0, 0.0, 1.0, 0.0);
  }

  return self;
}

- (void)dealloc
{
  CGColorRelease(_shadowColor);

  if (_longPressGestureRecognizer) {
    _longPressGestureRecognizer.delegate = nil;
    [_longPressGestureRecognizer removeTarget:nil action:NULL];
    [self.view removeGestureRecognizer:_longPressGestureRecognizer];
  }
}

#pragma mark - Description

- (NSString *)_plainStringForDescription
{
  NSString *plainString = [[self.attributedText string] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  if (plainString.length > 50) {
    plainString = [[plainString substringToIndex:50] stringByAppendingString:@"\u2026"];
  }
  return plainString;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [super propertiesForDescription];
  NSString *plainString = [self _plainStringForDescription];
  if (plainString.length > 0) {
    [result insertObject:@{ @"text" : ASStringWithQuotesIfMultiword(plainString) } atIndex:0];
  }
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray *result = [super propertiesForDebugDescription];
  NSString *plainString = [self _plainStringForDescription];
  if (plainString.length > 0) {
    [result insertObject:@{ @"text" : ASStringWithQuotesIfMultiword(plainString) } atIndex:0];
  }
  return result;
}

#pragma mark - ASDisplayNode

- (void)clearContents
{
  // We discard the backing store and renderer to prevent the very large
  // memory overhead of maintaining these for all text nodes.  They can be
  // regenerated when layout is necessary.
  [super clearContents];      // ASDisplayNode will set layer.contents = nil
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

#pragma mark - Renderer Management

- (ASTextKitRenderer *)_renderer
{
  CGSize constrainedSize = self.threadSafeBounds.size;
  return [self _rendererWithBoundsSlow:{.size = constrainedSize}];
}

- (ASTextKitRenderer *)_rendererWithBoundsSlow:(CGRect)bounds
{
  ASDN::MutexLocker l(__instanceLock__);
  bounds.size.width -= (_textContainerInset.left + _textContainerInset.right);
  bounds.size.height -= (_textContainerInset.top + _textContainerInset.bottom);
  return rendererForAttributes([self _rendererAttributes], bounds.size);
}


- (ASTextKitAttributes)_rendererAttributes
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return {
    .attributedString = _attributedText,
    .truncationAttributedString = [self _locked_composedTruncationText],
    .lineBreakMode = _truncationMode,
    .maximumNumberOfLines = _maximumNumberOfLines,
    .exclusionPaths = _exclusionPaths,
    // use the property getter so a subclass can provide these scale factors on demand if desired
    .pointSizeScaleFactors = self.pointSizeScaleFactors,
    .shadowOffset = _shadowOffset,
    .shadowColor = _cachedShadowUIColor,
    .shadowOpacity = _shadowOpacity,
    .shadowRadius = _shadowRadius
  };
}

#pragma mark - Layout and Sizing

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
  __instanceLock__.lock();
    BOOL needsUpdate = !UIEdgeInsetsEqualToEdgeInsets(textContainerInset, _textContainerInset);
    if (needsUpdate) {
      _textContainerInset = textContainerInset;
    }
  __instanceLock__.unlock();

  if (needsUpdate) {
    [self setNeedsLayout];
  }
}

- (UIEdgeInsets)textContainerInset
{
  ASDN::MutexLocker l(__instanceLock__);
  return _textContainerInset;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDN::MutexLocker l(__instanceLock__);
  
  ASDisplayNodeAssert(constrainedSize.width >= 0, @"Constrained width for text (%f) is too  narrow", constrainedSize.width);
  ASDisplayNodeAssert(constrainedSize.height >= 0, @"Constrained height for text (%f) is too short", constrainedSize.height);
  
  // Cache the original constrained size for final size calculateion
  CGSize originalConstrainedSize = constrainedSize;

  [self setNeedsDisplay];
  
  ASTextKitRenderer *renderer = [self _rendererWithBoundsSlow:{.size = constrainedSize}];
  CGSize size = renderer.size;
  if (_attributedText.length > 0) {
    self.style.ascender = [[self class] ascenderWithAttributedString:_attributedText];
    self.style.descender = [[_attributedText attribute:NSFontAttributeName atIndex:_attributedText.length - 1 effectiveRange:NULL] descender];
    if (renderer.currentScaleFactor > 0 && renderer.currentScaleFactor < 1.0) {
      // while not perfect, this is a good estimate of what the ascender of the scaled font will be.
      self.style.ascender *= renderer.currentScaleFactor;
      self.style.descender *= renderer.currentScaleFactor;
    }
  }
  
  // Add the constrained size back textContainerInset
  size.width += (_textContainerInset.left + _textContainerInset.right);
  size.height += (_textContainerInset.top + _textContainerInset.bottom);
  
  return CGSizeMake(std::fmin(size.width, originalConstrainedSize.width),
                    std::fmin(size.height, originalConstrainedSize.height));
}

#pragma mark - Modifying User Text

// Returns the ascender of the first character in attributedString by also including the line height if specified in paragraph style.
+ (CGFloat)ascenderWithAttributedString:(NSAttributedString *)attributedString 
{
  UIFont *font = [attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
  NSParagraphStyle *paragraphStyle = [attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  if (!paragraphStyle) {
    return font.ascender;
  }
  CGFloat lineHeight = MAX(font.lineHeight, paragraphStyle.minimumLineHeight);
  if (paragraphStyle.maximumLineHeight > 0) {
    lineHeight = MIN(lineHeight, paragraphStyle.maximumLineHeight);
  }
  return lineHeight + font.descender;
}

- (NSAttributedString *)attributedText
{
  ASDN::MutexLocker l(__instanceLock__);
  return _attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  
  if (attributedText == nil) {
    attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:nil];
  }
  
  // Don't hold textLock for too long.
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (ASObjectIsEqual(attributedText, _attributedText)) {
      return;
    }

    _attributedText = ASCleanseAttributedStringOfCoreTextAttributes(attributedText);
#if AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS
	  [ASTextNode _registerAttributedText:_attributedText];
#endif
  }
    
  // Since truncation text matches style of attributedText, invalidate it now.
  [self _invalidateTruncationText];
  
  NSUInteger length = attributedText.length;
  if (length > 0) {
    self.style.ascender = [[self class] ascenderWithAttributedString:attributedText];
    self.style.descender = [[attributedText attribute:NSFontAttributeName atIndex:attributedText.length - 1 effectiveRange:NULL] descender];
  }

  // Tell the display node superclasses that the cached layout is incorrect now
  [self setNeedsLayout];

  // Force display to create renderer with new size and redisplay with new string
  [self setNeedsDisplay];
  
  
  // Accessiblity
  self.accessibilityLabel = attributedText.string;
  self.isAccessibilityElement = (length != 0); // We're an accessibility element by default if there is a string.
}

#pragma mark - Text Layout

- (void)setExclusionPaths:(NSArray *)exclusionPaths
{
  {
    ASDN::MutexLocker l(__instanceLock__);
  
    if (ASObjectIsEqual(exclusionPaths, _exclusionPaths)) {
      return;
    }
    
    _exclusionPaths = [exclusionPaths copy];
  }
  
  [self setNeedsLayout];
  [self setNeedsDisplay];
}

- (NSArray *)exclusionPaths
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _exclusionPaths;
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  ASDN::MutexLocker l(__instanceLock__);
  
  _drawParameter = {
    .backgroundColor = self.backgroundColor,
    .bounds = self.bounds
  };
  return nil;
}


- (void)drawRect:(CGRect)bounds withParameters:(id <NSObject>)p isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;
{
  ASDN::MutexLocker l(__instanceLock__);

  ASTextNodeDrawParameter drawParameter = _drawParameter;
  CGRect drawParameterBounds = drawParameter.bounds;
  UIColor *backgroundColor = isRasterizing ? nil : drawParameter.backgroundColor;
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  ASDisplayNodeAssert(context, @"This is no good without a context.");
  
  CGContextSaveGState(context);
  
  CGContextTranslateCTM(context, _textContainerInset.left, _textContainerInset.top);
  
  ASTextKitRenderer *renderer = [self _rendererWithBoundsSlow:drawParameterBounds];
  
  // Fill background
  if (backgroundColor != nil) {
    [backgroundColor setFill];
    UIRectFillUsingBlendMode(CGContextGetClipBoundingBox(context), kCGBlendModeCopy);
  }
  
  // Draw text
  [renderer drawInContext:context bounds:drawParameterBounds];
  
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
  
  ASDN::MutexLocker l(__instanceLock__);
  
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
    CGFloat currentDistance = std::sqrt(std::pow(point.x - glyphLocation.x, 2.f) + std::pow(point.y - glyphLocation.y, 2.f));
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
  ASDN::MutexLocker l(__instanceLock__);
  
  return _highlightStyle;
}

- (void)setHighlightStyle:(ASTextNodeHighlightStyle)highlightStyle
{
  ASDN::MutexLocker l(__instanceLock__);
  
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
        ASDN::MutexLocker l(__instanceLock__);
        ASTextKitRenderer *renderer = [self _renderer];

        NSArray *highlightRects = [renderer rectsForTextRange:highlightRange measureOption:ASTextKitRendererMeasureOptionBlock];
        NSMutableArray *converted = [NSMutableArray arrayWithCapacity:highlightRects.count];
        for (NSValue *rectValue in highlightRects) {
          UIEdgeInsets shadowPadding = renderer.shadower.shadowPadding;
          CGRect rendererRect = ASTextNodeAdjustRenderRectForShadowPadding(rectValue.CGRectValue, shadowPadding);

          // The rects returned from renderer don't have `textContainerInset`,
          // as well as they are using the `constrainedSize` for layout,
          // so we can simply increase the rect by insets to get the full blown layout.
          rendererRect.size.width += _textContainerInset.left + _textContainerInset.right;
          rendererRect.size.height += _textContainerInset.top + _textContainerInset.bottom;

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
  ASDN::MutexLocker l(__instanceLock__);
  
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
  ASDN::MutexLocker l(__instanceLock__);
  
  CGRect rect = [[self _renderer] trailingRect];
  return ASTextNodeAdjustRenderRectForShadowPadding(rect, self.shadowPadding);
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  ASDN::MutexLocker l(__instanceLock__);
  
  CGRect frame = [[self _renderer] frameForTextRange:textRange];
  return ASTextNodeAdjustRenderRectForShadowPadding(frame, self.shadowPadding);
}

#pragma mark - Placeholders

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  ASDN::MutexLocker l(__instanceLock__);
  
  _placeholderColor = placeholderColor;

  // prevent placeholders if we don't have a color
  self.placeholderEnabled = placeholderColor != nil;
}

- (UIImage *)placeholderImage
{
  // FIXME: Replace this implementation with reusable CALayers that have .backgroundColor set.
  // This would completely eliminate the memory and performance cost of the backing store.
  CGSize size = self.calculatedSize;
  if ((size.width * size.height) < CGFLOAT_EPSILON) {
    return nil;
  }
  
  ASDN::MutexLocker l(__instanceLock__);
  
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
      ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);
  
  return (_highlightedLinkAttributeValue != nil && ![self _pendingTruncationTap]) && _delegate != nil;
}

- (BOOL)_pendingTruncationTap
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return [_highlightedLinkAttributeName isEqualToString:ASTextNodeTruncationTokenAttributeName];
}

#pragma mark - Shadow Properties

- (CGColorRef)shadowColor
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowColor;
}

- (void)setShadowColor:(CGColorRef)shadowColor
{
  __instanceLock__.lock();

  if (_shadowColor != shadowColor && CGColorEqualToColor(shadowColor, _shadowColor) == NO) {
    CGColorRelease(_shadowColor);
    _shadowColor = CGColorRetain(shadowColor);
    _cachedShadowUIColor = [UIColor colorWithCGColor:shadowColor];
    __instanceLock__.unlock();
    
    [self setNeedsDisplay];
    return;
  }

  __instanceLock__.unlock();
}

- (CGSize)shadowOffset
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (CGSizeEqualToSize(_shadowOffset, shadowOffset)) {
      return;
    }
    _shadowOffset = shadowOffset;
  }

  [self setNeedsDisplay];
}

- (CGFloat)shadowOpacity
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowOpacity;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_shadowOpacity == shadowOpacity) {
      return;
    }
    
    _shadowOpacity = shadowOpacity;
  }
  
  [self setNeedsDisplay];
}

- (CGFloat)shadowRadius
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowRadius;
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_shadowRadius == shadowRadius) {
      return;
    }
    
    _shadowRadius = shadowRadius;
  }
  
  [self setNeedsDisplay];
}

- (UIEdgeInsets)shadowPadding
{
  return [self shadowPaddingWithRenderer:[self _renderer]];
}

- (UIEdgeInsets)shadowPaddingWithRenderer:(ASTextKitRenderer *)renderer
{
  ASDN::MutexLocker l(__instanceLock__);
  
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
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (ASObjectIsEqual(_truncationAttributedText, truncationAttributedText)) {
      return;
    }

    _truncationAttributedText = [truncationAttributedText copy];
  }

  [self _invalidateTruncationText];
}

- (void)setAdditionalTruncationMessage:(NSAttributedString *)additionalTruncationMessage
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (ASObjectIsEqual(_additionalTruncationMessage, additionalTruncationMessage)) {
      return;
    }

    _additionalTruncationMessage = [additionalTruncationMessage copy];
  }

  [self _invalidateTruncationText];
}

- (void)setTruncationMode:(NSLineBreakMode)truncationMode
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_truncationMode == truncationMode) {
      return;
    }

    _truncationMode = truncationMode;
  }
  
  [self setNeedsDisplay];
}

- (BOOL)isTruncated
{
  ASDN::MutexLocker l(__instanceLock__);
  
  ASTextKitRenderer *renderer = [self _renderer];
  return renderer.isTruncated;
}

- (void)setPointSizeScaleFactors:(NSArray *)pointSizeScaleFactors
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    if ([_pointSizeScaleFactors isEqualToArray:pointSizeScaleFactors]) {
      return;
    }
    
    _pointSizeScaleFactors = pointSizeScaleFactors;
  }

  [self setNeedsDisplay];
}

- (void)setMaximumNumberOfLines:(NSUInteger)maximumNumberOfLines
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_maximumNumberOfLines == maximumNumberOfLines) {
      return;
    }

    _maximumNumberOfLines = maximumNumberOfLines;
  }
  
  [self setNeedsDisplay];
}

- (NSUInteger)lineCount
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return [[self _renderer] lineCount];
}

#pragma mark - Truncation Message

- (void)_invalidateTruncationText
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    _composedTruncationText = nil;
  }

  [self setNeedsDisplay];
}

/**
 * @return the additional truncation message range within the as-rendered text.
 * Must be called from main thread
 */
- (NSRange)_additionalTruncationMessageRangeWithVisibleRange:(NSRange)visibleRange
{
  ASDN::MutexLocker l(__instanceLock__);
  
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
- (NSAttributedString *)_locked_composedTruncationText
{
  if (_composedTruncationText == nil) {
    if (_truncationAttributedText != nil && _additionalTruncationMessage != nil) {
      NSMutableAttributedString *newComposedTruncationString = [[NSMutableAttributedString alloc] initWithAttributedString:_truncationAttributedText];
      [newComposedTruncationString.mutableString appendString:@" "];
      [newComposedTruncationString appendAttributedString:_additionalTruncationMessage];
      _composedTruncationText = newComposedTruncationString;
    } else if (_truncationAttributedText != nil) {
      _composedTruncationText = _truncationAttributedText;
    } else if (_additionalTruncationMessage != nil) {
      _composedTruncationText = _additionalTruncationMessage;
    } else {
      _composedTruncationText = DefaultTruncationAttributedString();
    }
    _composedTruncationText = [self _locked_prepareTruncationStringForDrawing:_composedTruncationText];
  }
  return _composedTruncationText;
}

/**
 * - cleanses it of core text attributes so TextKit doesn't crash
 * - Adds whole-string attributes so the truncation message matches the styling
 * of the body text
 */
- (NSAttributedString *)_locked_prepareTruncationStringForDrawing:(NSAttributedString *)truncationString
{
  truncationString = ASCleanseAttributedStringOfCoreTextAttributes(truncationString);
  NSMutableAttributedString *truncationMutableString = [truncationString mutableCopy];
  // Grab the attributes from the full string
  if (_attributedText.length > 0) {
    NSAttributedString *originalString = _attributedText;
    NSInteger originalStringLength = _attributedText.length;
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

#if AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS
+ (void)_registerAttributedText:(NSAttributedString *)str
{
  static NSMutableArray *array;
  static NSLock *lock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    lock = [NSLock new];
    array = [NSMutableArray new];
  });
  [lock lock];
  [array addObject:str];
  if (array.count % 20 == 0) {
    NSLog(@"Got %d strings", (int)array.count);
  }
  if (array.count == 2000) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AttributedStrings.plist"];
    NSAssert([NSKeyedArchiver archiveRootObject:array toFile:path], nil);
    NSLog(@"Saved to %@", path);
  }
  [lock unlock];
}
#endif

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
