//
//  ASTraitCollection.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//


#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASTraitCollection;
@protocol ASLayoutElement;

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

#pragma mark - ASPrimitiveTraitCollection

typedef struct ASPrimitiveTraitCollection {
  CGFloat displayScale;
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceIdiom userInterfaceIdiom;
  UIUserInterfaceSizeClass verticalSizeClass;
  UIForceTouchCapability forceTouchCapability;

  CGSize containerSize;
} ASPrimitiveTraitCollection;

/**
 * Creates ASPrimitiveTraitCollection with default values.
 */
extern ASPrimitiveTraitCollection ASPrimitiveTraitCollectionMakeDefault();

/**
 * Creates a ASPrimitiveTraitCollection from a given UITraitCollection.
 */
extern ASPrimitiveTraitCollection ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection);


/**
 * Compares two ASPrimitiveTraitCollection to determine if they are the same.
 */
extern BOOL ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(ASPrimitiveTraitCollection lhs, ASPrimitiveTraitCollection rhs);

/**
 * Returns a string representation of a ASPrimitiveTraitCollection.
 */
extern NSString *NSStringFromASPrimitiveTraitCollection(ASPrimitiveTraitCollection traits);

/**
 * This function will walk the layout element hierarchy and updates the layout element trait collection for every
 * layout element within the hierarchy.
 */
extern void ASTraitCollectionPropagateDown(id<ASLayoutElement> root, ASPrimitiveTraitCollection traitCollection);

/// For backward compatibility reasons we redefine the old layout element trait collection struct name
#define ASEnvironmentTraitCollection ASPrimitiveTraitCollection
#define ASEnvironmentTraitCollectionMakeDefault ASPrimitiveTraitCollectionMakeDefault

ASDISPLAYNODE_EXTERN_C_END

/**
 * Abstraction on top of UITraitCollection for propagation within AsyncDisplayKit-Layout
 */
@protocol ASTraitEnvironment <NSObject>

/**
 * Returns a struct-representation of the environment's ASEnvironmentDisplayTraits. This only exists as a internal
 * convenience method. Users should access the trait collections through the NSObject based asyncTraitCollection API
 */
- (ASPrimitiveTraitCollection)primitiveTraitCollection;

/**
 * Sets a trait collection on this environment state.
 */
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection;

/**
 * Returns an NSObject-representation of the environment's ASEnvironmentDisplayTraits
 */
- (ASTraitCollection *)asyncTraitCollection;

/**
 * Deprecated and should be replaced by the methods from above
 */
- (ASEnvironmentTraitCollection)environmentTraitCollection;
- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traitCollection;


@end

#define ASPrimitiveTraitCollectionDeprecatedImplementation \
- (ASEnvironmentTraitCollection)environmentTraitCollection\
{\
  return self.primitiveTraitCollection;\
}\
- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traitCollection\
{\
  [self setPrimitiveTraitCollection:traitCollection];\
}\

#define ASLayoutElementCollectionTableSetTraitCollection(lock) \
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection\
{\
  ASDN::MutexLocker l(lock);\
\
  ASPrimitiveTraitCollection oldTraits = self.primitiveTraitCollection;\
  [super setPrimitiveTraitCollection:traitCollection];\
\
  /* Extra Trait Collection Handling */\
\
  /* If the node is not loaded  yet don't do anything as otherwise the access of the view will trigger a load */\
  if (! self.isNodeLoaded) { return; }\
\
  ASPrimitiveTraitCollection currentTraits = self.primitiveTraitCollection;\
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(currentTraits, oldTraits) == NO) {\
    [self.dataController environmentDidChange];\
  }\
}\

#pragma mark - ASTraitCollection

AS_SUBCLASSING_RESTRICTED
@interface ASTraitCollection : NSObject

@property (nonatomic, assign, readonly) CGFloat displayScale;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, assign, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic, assign, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, assign, readonly) CGSize containerSize;

+ (ASTraitCollection *)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize;


+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                         containerSize:(CGSize)windowSize;


- (ASPrimitiveTraitCollection)primitiveTraitCollection;
- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end

NS_ASSUME_NONNULL_END
