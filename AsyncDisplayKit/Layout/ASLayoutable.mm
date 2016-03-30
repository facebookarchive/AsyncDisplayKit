//
//  ASLayoutablePrivate.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutablePrivate.h"
#import "ASInternalHelpers.h"
#import "ASEnvironmentInternal.h"
#import "ASDisplayNodeInternal.h"
#import "ASTextNode.h"
#import "ASLayoutSpec.h"

#import "pthread.h"
#import <map>
#import <iterator>
#import "ASThread.h"

int32_t const ASLayoutableContextInvalidTransitionID = 0;
int32_t const ASLayoutableContextDefaultTransitionID = ASLayoutableContextInvalidTransitionID + 1;

static inline ASLayoutableContext _ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  struct ASLayoutableContext context;
  context.transitionID = transitionID;
  context.needsVisualizeNode = needsVisualizeNode;
  return context;
}

static inline BOOL _IsValidTransitionID(int32_t transitionID)
{
  return transitionID > ASLayoutableContextInvalidTransitionID;
}

struct ASLayoutableContext const ASLayoutableContextNull = _ASLayoutableContextMake(ASLayoutableContextInvalidTransitionID, NO);

BOOL ASLayoutableContextIsNull(struct ASLayoutableContext context)
{
  return !_IsValidTransitionID(context.transitionID);
}

ASLayoutableContext ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  NSCAssert(_IsValidTransitionID(transitionID), @"Invalid transition ID");
  return _ASLayoutableContextMake(transitionID, needsVisualizeNode);
}

// Note: This is a non-recursive static lock. If it needs to be recursive, use ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER
static ASDN::StaticMutex _layoutableContextLock = ASDISPLAYNODE_MUTEX_INITIALIZER;
static std::map<mach_port_t, ASLayoutableContext> layoutableContextMap;

static inline mach_port_t ASLayoutableGetCurrentContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutableSetCurrentContext(struct ASLayoutableContext context)
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  layoutableContextMap[key] = context;
}

struct ASLayoutableContext ASLayoutableGetCurrentContext()
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  const auto it = layoutableContextMap.find(key);
  if (it != layoutableContextMap.end()) {
    // Found an interator with above key. "it->first" is the key itself, "it->second" is the context value.
    return it->second;
  }
  return ASLayoutableContextNull;
}

void ASLayoutableClearCurrentContext()
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  layoutableContextMap.erase(key);
}

/**
 *  Given an id<ASLayoutable>, set up layout options that are intrinsically defined by the layoutable.
 *
 *  While this could be done in the layoutable object itself, moving the logic into this helper function
 *  allows a custom spec to set up defaults without needing to alter the layoutable itself. For example,
 *  image you were creating a custom baseline spec that needed ascender/descender. To assign values automatically
 *  when a text node's attribute string is set, you would need to subclass ASTextNode and assign the values in the
 *  override of setAttributeString. However, assigning the defaults via this function allows you to create a
 *  custom spec without the need to create a subclass of ASTextNode.
 *
 *  @param layoutable The layoutable object to inspect for default intrinsic layout option values
 */
void ASLayoutableSetValuesForLayoutable(id<ASLayoutable> layoutable)
{
  //ASDN::MutexLocker l(_propertyLock);
  if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    ASDisplayNode *displayNode = (ASDisplayNode *)layoutable;
    displayNode.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize), ASRelativeSizeMakeWithCGSize(displayNode.preferredFrameSize));
    
    if ([layoutable isKindOfClass:[ASTextNode class]]) {
      ASTextNode *textNode = (ASTextNode *)layoutable;
      NSAttributedString *attributedString = textNode.attributedString;
      if (attributedString.length > 0) {
        CGFloat screenScale = ASScreenScale();
        textNode.ascender = round([[attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ascender] * screenScale)/screenScale;
        textNode.descender = round([[attributedString attribute:NSFontAttributeName atIndex:attributedString.length - 1 effectiveRange:NULL] descender] * screenScale)/screenScale;
      }
    }
    
  }
}


#pragma mark - ASLayoutOptionsForwarding

/**
 *  Both an ASDisplayNode and an ASLayoutSpec conform to ASLayoutable. There are several properties
 *  in ASLayoutable that are used when a node or spec is used in a layout spec.
 *  These properties are provided for convenience, as they are forwards to the node or spec's
 *  properties. Instead of duplicating the property forwarding in both classes, we
 *  create a define that allows us to easily implement the forwards in one place.
 *
 *  If you create a custom layout spec, we recommend this stragety if you decide to extend
 *  ASDisplayNode and ASLayoutSpec to provide convenience properties for any options that your
 *  layoutSpec may require.
 */

#define ASEnvironmentLayoutOptionsForwarding \
- (ASEnvironmentLayoutOptionsState *)layoutOptionsState\
{\
  return &(self.environmentCollection->layoutOptionsState);\
}\
- (void)propagateUpLayoutOptionsState\
{\
  id<ASEnvironment> parent = [self parent];\
  if (![parent supportsMultipleChildren]) {\
    ASEnvironmentStatePropagateUp(parent, self.environmentCollection->layoutOptionsState);\
  }\
}\
\
- (CGFloat)spacingAfter\
{\
  return self.layoutOptionsState->spacingAfter;\
}\
\
- (void)setSpacingAfter:(CGFloat)spacingAfter\
{\
  self.layoutOptionsState->spacingAfter = spacingAfter;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)spacingBefore\
{\
  return self.layoutOptionsState->spacingBefore;\
}\
\
- (void)setSpacingBefore:(CGFloat)spacingBefore\
{\
  self.layoutOptionsState->spacingBefore = spacingBefore;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (BOOL)flexGrow\
{\
  return self.layoutOptionsState->flexGrow;\
}\
\
- (void)setFlexGrow:(BOOL)flexGrow\
{\
  self.layoutOptionsState->flexGrow = flexGrow;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (BOOL)flexShrink\
{\
  return self.layoutOptionsState->flexShrink;\
}\
\
- (void)setFlexShrink:(BOOL)flexShrink\
{\
  self.layoutOptionsState->flexShrink = flexShrink;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (ASRelativeDimension)flexBasis\
{\
  return self.layoutOptionsState->flexBasis;\
}\
\
- (void)setFlexBasis:(ASRelativeDimension)flexBasis\
{\
  self.layoutOptionsState->flexBasis = flexBasis;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (ASStackLayoutAlignSelf)alignSelf\
{\
  return self.layoutOptionsState->alignSelf;\
}\
\
- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf\
{\
  self.layoutOptionsState->alignSelf = alignSelf;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)ascender\
{\
  return self.layoutOptionsState->ascender;\
}\
\
- (void)setAscender:(CGFloat)ascender\
{\
  self.layoutOptionsState->ascender = ascender;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)descender\
{\
  return self.layoutOptionsState->descender;\
}\
\
- (void)setDescender:(CGFloat)descender\
{\
  self.layoutOptionsState->descender = descender;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (ASRelativeSizeRange)sizeRange\
{\
  return self.layoutOptionsState->sizeRange;\
}\
\
- (void)setSizeRange:(ASRelativeSizeRange)sizeRange\
{\
  self.layoutOptionsState->sizeRange = sizeRange;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGPoint)layoutPosition\
{\
  return self.layoutOptionsState->layoutPosition;\
}\
\
- (void)setLayoutPosition:(CGPoint)layoutPosition\
{\
  self.layoutOptionsState->layoutPosition = layoutPosition;\
  [self propagateUpLayoutOptionsState];\
}\


@implementation ASDisplayNode(ASLayoutOptionsForwarding)
ASEnvironmentLayoutOptionsForwarding
@end

@implementation ASLayoutSpec(ASLayoutOptionsForwarding)
ASEnvironmentLayoutOptionsForwarding
@end

