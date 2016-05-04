/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASEnvironment.h>

@interface ASDisplayTraits : NSObject

@property (nonatomic, assign) BOOL isMutable;

@property (nonatomic, assign) CGFloat displayScale;
@property (nonatomic, assign) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, assign) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, assign) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic, assign) UIForceTouchCapability forceTouchCapability;

+ (ASDisplayTraits *)displayTraitsWithASEnvironmentDisplayTraits:(ASEnvironmentDisplayTraits)traits;
+ (ASDisplayTraits *)displayTraitsWithUITraitCollection:(UITraitCollection *)traitCollection;

- (ASEnvironmentDisplayTraits)environmentDisplayTraits;

@end
