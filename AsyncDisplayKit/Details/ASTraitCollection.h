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
#import <AsyncDisplayKit/ASEnvironment.h>

@interface ASTraitCollection : NSObject

@property (nonatomic, assign, readonly) CGFloat displayScale;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, assign, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic, assign, readonly) UIForceTouchCapability forceTouchCapability;

/**
 *  An optional context to pass along with an ASTraitCollection.
 *  This can be used to pass any internal state to all subnodes via the ASTraitCollection that is not
 *  included in UITraitCollection. This could range from more fine-tuned size classes to a class of
 *  constants that is based upon the new trait collection.
 *
 *  Be aware that internally this context is held by a C struct which cannot retain the pointer. 
 *  ASTraitCollection is generally a very short-lived class, existing only to provide a non-struct API
 *  to trait collections. When an ASTraitCollection is returned via one of ASViewController's 2 
 *  custom trait collection creation blocks, traitCollectionContext is assigned to the VC's traitCollectionContext.
 *  This makes sure that the VC is the owner of the context and ASEnvironmentTraitCollections will not
 *  have a reference to a dangling pointer.
 */
@property (nonatomic, strong, readonly) id traitCollectionContext;


+ (ASTraitCollection *)traitCollectionWithASEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traits;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                     traitCollectionContext:(id)traitCollectionContext;


+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                traitCollectionContext:(id)traitCollectionContext;


- (ASEnvironmentTraitCollection)environmentTraitCollection;
- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end
