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
@property (nonatomic, assign, readonly) CGSize containerSize;


+ (ASTraitCollection *)traitCollectionWithASEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traits;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                        containerSize:(CGSize)windowSize;


+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                   containerSize:(CGSize)windowSize;


- (ASEnvironmentTraitCollection)environmentTraitCollection;
- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end
