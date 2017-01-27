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

ASDISPLAYNODE_EXTERN_C_BEGIN

#pragma mark - ASLayoutElementTraitCollection

typedef struct ASLayoutElementTraitCollection {
  CGFloat displayScale;
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceIdiom userInterfaceIdiom;
  UIUserInterfaceSizeClass verticalSizeClass;
  UIForceTouchCapability forceTouchCapability;

  CGSize containerSize;
} ASLayoutElementTraitCollection;

/// Deprecation
#define ASEnvironmentTraitCollection ASLayoutElementTraitCollection

/**
 * Creates ASLayoutElementTraitCollection with default values.
 */
extern ASLayoutElementTraitCollection ASLayoutElementTraitCollectionMakeDefault();

/**
 * Creates a ASLayoutElementTraitCollection from a given UITraitCollection.
 */
extern ASLayoutElementTraitCollection ASLayoutElementTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection);


/**
 * Compares two ASLayoutElementTraitCollections to determine if they are the same.
 */
extern BOOL ASLayoutElementTraitCollectionIsEqualToASLayoutElementTraitCollection(ASLayoutElementTraitCollection lhs, ASLayoutElementTraitCollection rhs);

/**
 * Returns a string representation of a ASLayoutElementTraitCollection.
 */
extern NSString *NSStringFromASLayoutElementTraitCollection(ASLayoutElementTraitCollection traits);

/**
 * This function will walk the layout element hierarchy and updates the layout element trait collection for every
 * layout element within the hierarchy.
 */
extern void ASLayoutElementTraitCollectionPropagateDown(id<ASLayoutElement> root, ASLayoutElementTraitCollection traitCollection);

ASDISPLAYNODE_EXTERN_C_END

/**
 * Abstraction on top of UITraitCollection for propagation within AsyncDisplayKit-Layout
 */
@protocol ASLayoutElementTraitEnvironment <NSObject>

/**
 * Returns a struct-representation of the environment's ASEnvironmentDisplayTraits. This only exists as a internal
 * convenience method. Users should access the trait collections through the NSObject based asyncTraitCollection API
 */
- (ASLayoutElementTraitCollection)layoutElementTraitCollection;

/**
 * Sets a trait collection on this environment state.
 */
- (void)setLayoutElementTraitCollection:(ASLayoutElementTraitCollection)traitCollection;

/**
 * Returns an NSObject-representation of the environment's ASEnvironmentDisplayTraits
 */
- (ASTraitCollection *)asyncTraitCollection;

/**
 * Deprecated and should be replaced by the methods from above
 */
- (ASEnvironmentTraitCollection)environmentTraitCollection;
- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traitCollection;;


@end

#define ASLayoutElementTraitCollectionDeprecatedImplementation \
- (ASEnvironmentTraitCollection)environmentTraitCollection\
{\
  return self.layoutElementTraitCollection;\
}\
- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traitCollection\
{\
  [self setLayoutElementTraitCollection:traitCollection];\
}\

#define ASLayoutElementCollectionTableSetTraitCollection(lock) \
- (void)setLayoutElementTraitCollection:(ASLayoutElementTraitCollection)traitCollection\
{\
  ASDN::MutexLocker l(lock);\
\
  ASLayoutElementTraitCollection oldTraits = self.layoutElementTraitCollection;\
  [super setLayoutElementTraitCollection:traitCollection];\
\
  /* Extra Trait Collection Handling */\
\
  /* If the node is not loaded  yet don't do anything as otherwise the access of the view will trigger a load*/\
  if (!self.isNodeLoaded) { return; }\
\
  ASLayoutElementTraitCollection currentTraits = self.layoutElementTraitCollection;\
  if (ASLayoutElementTraitCollectionIsEqualToASLayoutElementTraitCollection(currentTraits, oldTraits) == NO) {\
    /* Must dispatch to main for self.view && [self.view.dataController completedNodes]*/\
    ASPerformBlockOnMainThread(^{\
      NSArray<NSArray <ASCellNode *> *> *completedNodes = [self.view.dataController completedNodes];\
      for (NSArray *sectionArray in completedNodes) {\
        for (ASCellNode *cellNode in sectionArray) {\
          ASLayoutElementTraitCollectionPropagateDown(cellNode, currentTraits);\
        }\
      }\
    });\
  }\
}\

#pragma mark - ASTraitCollection

@interface ASTraitCollection : NSObject

@property (nonatomic, assign, readonly) CGFloat displayScale;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, assign, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic, assign, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, assign, readonly) CGSize containerSize;


+ (ASTraitCollection *)traitCollectionWithASLayoutElementTraitCollection:(ASLayoutElementTraitCollection)traits;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize;


+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                         containerSize:(CGSize)windowSize;


- (ASLayoutElementTraitCollection)layoutElementTraitCollection;
- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end
