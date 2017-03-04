//
//  ASLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayout.h>

#import <queue>

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASRectTable.h>

CGPoint const CGPointNull = {NAN, NAN};

extern BOOL CGPointIsNull(CGPoint point)
{
  return isnan(point.x) && isnan(point.y);
}

/**
 * Creates an defined number of "    |" indent blocks for the recursive description.
 */
static inline NSString * descriptionIndents(NSUInteger indents)
{
  NSMutableString *description = [NSMutableString string];
  for (NSUInteger i = 0; i < indents; i++) {
    [description appendString:@"    |"];
  }
  if (indents > 0) {
    [description appendString:@" "];
  }
  return description;
}

@interface ASLayout () <ASDescriptionProvider>
{
  ASLayoutElementType _layoutElementType;
}
/**
 * A boolean describing if the current layout has been flattened.
 */
@property (nonatomic, getter=isFlattened) BOOL flattened;

/*
 * Caches all sublayouts if set to YES or destroys the sublayout cache if set to NO. Defaults to YES
 */
@property (nonatomic, assign) BOOL retainSublayoutLayoutElements;

/**
 * Array for explicitly retain sublayout layout elements in case they are created and references in layoutSpecThatFits: and no one else will hold a strong reference on it
 */
@property (nonatomic, strong) NSMutableArray<id<ASLayoutElement>> *sublayoutLayoutElements;

@property (nonatomic, strong, readonly) ASRectTable<id<ASLayoutElement>, id> *elementToRectTable;

@end

@implementation ASLayout

@dynamic frame, type;

- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                 size:(CGSize)size
                             position:(CGPoint)position
                           sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  NSParameterAssert(layoutElement);
  
  self = [super init];
  if (self) {
#if DEBUG
    for (ASLayout *sublayout in sublayouts) {
      ASDisplayNodeAssert(CGPointIsNull(sublayout.position) == NO, @"Invalid position is not allowed in sublayout.");
    }
#endif
    
    _layoutElement = layoutElement;
    
    // Read this now to avoid @c weak overhead later.
    _layoutElementType = layoutElement.layoutElementType;
    
    if (!ASIsCGSizeValidForSize(size)) {
      ASDisplayNodeAssert(NO, @"layoutSize is invalid and unsafe to provide to Core Animation! Release configurations will force to 0, 0.  Size = %@, node = %@", NSStringFromCGSize(size), layoutElement);
      size = CGSizeZero;
    } else {
      size = CGSizeMake(ASCeilPixelValue(size.width), ASCeilPixelValue(size.height));
    }
    _size = size;
    
    if (CGPointIsNull(position) == NO) {
      _position = CGPointMake(ASCeilPixelValue(position.x), ASCeilPixelValue(position.y));
    } else {
      _position = position;
    }

    _sublayouts = sublayouts != nil ? [sublayouts copy] : @[];

    _elementToRectTable = [ASRectTable rectTableForWeakObjectPointers];
    for (ASLayout *layout in sublayouts) {
      [_elementToRectTable setRect:layout.frame forKey:layout.layoutElement];
    }
    
    _flattened = NO;
    _retainSublayoutLayoutElements = NO;
  }
  
  return self;
}

- (instancetype)init
{
  ASDisplayNodeAssert(NO, @"Use the designated initializer");
  return [self init];
}

#pragma mark - Class Constructors

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                               position:(CGPoint)position
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [[self alloc] initWithLayoutElement:layoutElement
                                        size:size
                                    position:position
                                  sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:CGPointNull
                            sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement size:(CGSize)size
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:CGPointNull
                            sublayouts:nil];
}

+ (instancetype)layoutWithLayout:(ASLayout *)layout position:(CGPoint)position
{
  return [self layoutWithLayoutElement:layout.layoutElement
                                  size:layout.size
                              position:position
                            sublayouts:layout.sublayouts];
}

#pragma mark - Sublayout Elements Caching

- (void)setRetainSublayoutLayoutElements:(BOOL)retainSublayoutLayoutElements
{
  if (_retainSublayoutLayoutElements != retainSublayoutLayoutElements) {
    _retainSublayoutLayoutElements = retainSublayoutLayoutElements;
    
    if (retainSublayoutLayoutElements == NO) {
      _sublayoutLayoutElements = nil;
    } else {
      // Add sublayouts layout elements to an internal array to retain it while the layout lives
      NSUInteger sublayoutCount = _sublayouts.count;
      if (sublayoutCount > 0) {
        _sublayoutLayoutElements = [NSMutableArray arrayWithCapacity:sublayoutCount];
        for (ASLayout *sublayout in _sublayouts) {
          [_sublayoutLayoutElements addObject:sublayout.layoutElement];
        }
      }
    }
  }
}

#pragma mark - Layout Flattening

- (ASLayout *)filteredNodeLayoutTree
{
  NSMutableArray *flattenedSublayouts = [NSMutableArray array];
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
  };
  
  // Queue used to keep track of sublayouts while traversing this layout in a DFS fashion.
  std::deque<Context> queue;
  queue.push_front({self, CGPointZero});
  
  while (!queue.empty()) {
    Context context = queue.front();
    queue.pop_front();

    if (self != context.layout && context.layout.type == ASLayoutElementTypeDisplayNode) {
      ASLayout *layout = [ASLayout layoutWithLayout:context.layout position:context.absolutePosition];
      layout.flattened = YES;
      [flattenedSublayouts addObject:layout];
    }
    
    std::vector<Context> sublayoutContexts;
    for (ASLayout *sublayout in context.layout.sublayouts) {
      if (sublayout.isFlattened == NO) {
        sublayoutContexts.push_back({sublayout, context.absolutePosition + sublayout.position});
      }
    }
    queue.insert(queue.cbegin(), sublayoutContexts.begin(), sublayoutContexts.end());
  }
  
  ASLayout *layout = [ASLayout layoutWithLayoutElement:_layoutElement size:_size position:CGPointZero sublayouts:flattenedSublayouts];
  layout.retainSublayoutLayoutElements = YES;
  return layout;
}

#pragma mark - Accessors

- (ASLayoutElementType)type
{
  return _layoutElementType;
}

- (CGRect)frameForElement:(id<ASLayoutElement>)layoutElement
{
  return [_elementToRectTable rectForKey:layoutElement];
}

- (CGRect)frame
{
  CGRect subnodeFrame = CGRectZero;
  CGPoint adjustedOrigin = _position;
  if (isfinite(adjustedOrigin.x) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.x = 0;
  }
  if (isfinite(adjustedOrigin.y) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.y = 0;
  }
  subnodeFrame.origin = adjustedOrigin;
  
  CGSize adjustedSize = _size;
  if (isfinite(adjustedSize.width) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid size");
    adjustedSize.width = 0;
  }
  if (isfinite(adjustedSize.height) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedSize.height = 0;
  }
  subnodeFrame.size = adjustedSize;
  
  return subnodeFrame;
}

#pragma mark - Description

- (NSMutableArray <NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [NSMutableArray array];
  [result addObject:@{ @"layoutElement" : (self.layoutElement ?: (id)kCFNull) }];
  [result addObject:@{ @"position" : [NSValue valueWithCGPoint:self.position] }];
  [result addObject:@{ @"size" : [NSValue valueWithCGSize:self.size] }];
  return result;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)recursiveDescription
{
  return [self _recursiveDescriptionForLayout:self level:0];
}

- (NSString *)_recursiveDescriptionForLayout:(ASLayout *)layout level:(NSUInteger)level
{
  NSMutableString *description = [NSMutableString string];
  [description appendString:descriptionIndents(level)];
  [description appendString:[layout description]];
  for (ASLayout *sublayout in layout.sublayouts) {
    [description appendString:@"\n"];
    [description appendString:[self _recursiveDescriptionForLayout:sublayout level:level + 1]];
  }
  return description;
}

@end

@implementation ASLayout (Deprecation)

- (id <ASLayoutElement>)layoutableObject
{
  return self.layoutElement;
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size
{
  return [self layoutWithLayoutElement:layoutElement size:size];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size
                                sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutElement:layoutElement size:size sublayouts:sublayouts];
}

@end

ASLayout *ASCalculateLayout(id<ASLayoutElement> layoutElement, const ASSizeRange sizeRange, const CGSize parentSize)
{
  ASDisplayNodeCAssertNotNil(layoutElement, @"Not valid layoutElement passed in.");
  
  return [layoutElement layoutThatFits:sizeRange parentSize:parentSize];
}

ASLayout *ASCalculateRootLayout(id<ASLayoutElement> rootLayoutElement, const ASSizeRange sizeRange)
{
  ASLayout *layout = ASCalculateLayout(rootLayoutElement, sizeRange, sizeRange.max);
  // Here could specific verfication happen
  return layout;
}
