//
//  ASEnvironment.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import "ASDimension.h"
#import "ASStackLayoutDefines.h"
#import "ASRelativeSize.h"

@protocol ASEnvironment;
@class UITraitCollection;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

static const int kMaxEnvironmentStateBoolExtensions = 1;
static const int kMaxEnvironmentStateIntegerExtensions = 4;
static const int kMaxEnvironmentStateEdgeInsetExtensions = 1;

#pragma mark -

typedef struct ASEnvironmentStateExtensions {
  // Values to store extensions
  BOOL boolExtensions[kMaxEnvironmentStateBoolExtensions];
  NSInteger integerExtensions[kMaxEnvironmentStateIntegerExtensions];
  UIEdgeInsets edgeInsetsExtensions[kMaxEnvironmentStateEdgeInsetExtensions];
} ASEnvironmentStateExtensions;

#pragma mark - ASEnvironmentLayoutOptionsState

typedef struct ASEnvironmentLayoutOptionsState {
  CGFloat spacingBefore;// = 0;
  CGFloat spacingAfter;// = 0;
  BOOL flexGrow;// = NO;
  BOOL flexShrink;// = NO;
  ASRelativeDimension flexBasis;// = ASRelativeDimensionUnconstrained;
  ASStackLayoutAlignSelf alignSelf;// = ASStackLayoutAlignSelfAuto;
  CGFloat ascender;// = 0;
  CGFloat descender;// = 0;
  
  ASRelativeSizeRange sizeRange;// = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero));;
  CGPoint layoutPosition;// = CGPointZero;
  
  struct ASEnvironmentStateExtensions _extensions;
} ASEnvironmentLayoutOptionsState;


#pragma mark - ASEnvironmentHierarchyState

typedef struct ASEnvironmentHierarchyState {
  unsigned rasterized:1; // = NO
  unsigned rangeManaged:1; // = NO
  unsigned transitioningSupernodes:1; // = NO
  unsigned layoutPending:1; // = NO
} ASEnvironmentHierarchyState;

#pragma mark - ASEnvironmentDisplayTraits

typedef struct ASEnvironmentTraitCollection {
  CGFloat displayScale;
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceIdiom userInterfaceIdiom;
  UIUserInterfaceSizeClass verticalSizeClass;
  UIForceTouchCapability forceTouchCapability;
  
  // WARNING:
  // This pointer is in a C struct and therefore not managed by ARC. It is
  // an unsafe unretained pointer, so when you dereference it you better be
  // sure that it is valid.
  //
  // Use displayContext when you wish to pass view context specific data along with the
  // display traits to subnodes. This should be a piece of data owned by an
  // ASViewController, which will ensure that the data is still valid when laying out
  // its subviews. When the VC is dealloc'ed, the displayContext it created will also
  // be dealloced but any subnodes that are hanging around (why would they be?) will now
  // have a displayContext that points to a bad pointer.
  //
  // As an added precaution ASDisplayTraitsClearDisplayContext is called from ASVC's desctructor
  // which will propagate a nil displayContext to its subnodes.
  id __unsafe_unretained displayContext;
} ASEnvironmentTraitCollection;

extern void ASEnvironmentTraitCollectionUpdateDisplayContext(id<ASEnvironment> rootEnvironment, id _Nullable context);

extern ASEnvironmentTraitCollection ASEnvironmentTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection);
extern BOOL ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(ASEnvironmentTraitCollection lhs, ASEnvironmentTraitCollection rhs);

#pragma mark - ASEnvironmentState

typedef struct ASEnvironmentState {
  struct ASEnvironmentHierarchyState hierarchyState;
  struct ASEnvironmentLayoutOptionsState layoutOptionsState;
  struct ASEnvironmentTraitCollection environmentTraitCollection;
} ASEnvironmentState;
extern ASEnvironmentState ASEnvironmentStateMakeDefault();

ASDISPLAYNODE_EXTERN_C_END

@class ASTraitCollection;

#pragma mark - ASEnvironment

/**
 * ASEnvironment allows objects that conform to the ASEnvironment protocol to be able to propagate specific States
 * defined in an ASEnvironmentState up and down the ASEnvironment tree. To be able to define how merges of
 * States should happen, specific merge functions can be provided
 */
@protocol ASEnvironment <NSObject>

/// The environment collection of an object which class conforms to the ASEnvironment protocol
- (ASEnvironmentState)environmentState;
- (void)setEnvironmentState:(ASEnvironmentState)environmentState;

/// Returns the parent of an object which class conforms to the ASEnvironment protocol
- (id<ASEnvironment> _Nullable)parent;

/// Returns all children of an object which class conforms to the ASEnvironment protocol
- (nullable NSArray<id<ASEnvironment>> *)children;

/// Classes should implement this method and return YES / NO dependent if upward propagation is enabled or not 
- (BOOL)supportsUpwardPropagation;

/// Classes should implement this method and return YES / NO dependent if downware propagation is enabled or not
- (BOOL)supportsTraitsCollectionPropagation;

/// Returns an NSObject-representation of the environment's ASEnvironmentDisplayTraits
- (ASTraitCollection *)asyncTraitCollection;

/// Returns a struct-representation of the environment's ASEnvironmentDisplayTraits. This only exists as a internal
/// convenience method. Users should access the trait collections through the NSObject based asyncTraitCollection API
- (ASEnvironmentTraitCollection)environmentTraitCollection;

/// sets a trait collection on this environment state.
- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection;
@end

// ASCollection/TableNodes don't actually have ASCellNodes as subnodes. Because of this we can't rely on display trait
// downward propagation via ASEnvironment. Instead if the new environmentState has displayTraits that are different from
// the cells', then we propagate downward explicitly and request a relayout.
//
// If there is any new downward propagating state, it should be added to this define.
//
// This logic is used in both ASCollectionNode and ASTableNode
#define ASEnvironmentCollectionTableSetEnvironmentState(lock) \
- (void)setEnvironmentState:(ASEnvironmentState)environmentState\
{\
  ASDN::MutexLocker l(lock);\
  ASEnvironmentTraitCollection oldTraits = self.environmentState.environmentTraitCollection;\
  [super setEnvironmentState:environmentState];\
  ASEnvironmentTraitCollection currentTraits = environmentState.environmentTraitCollection;\
  if (ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(currentTraits, oldTraits) == NO) {\
    ASPerformBlockOnMainThread(^{\
      NSArray<NSArray <ASCellNode *> *> *completedNodes = [self.view.dataController completedNodes];\
      for (NSArray *sectionArray in completedNodes) {\
        for (ASCellNode *cellNode in sectionArray) {\
          ASEnvironmentStatePropagateDown(cellNode, currentTraits);\
          [cellNode setNeedsLayout];\
        }\
      }\
    });\
  }\
}\

NS_ASSUME_NONNULL_END
