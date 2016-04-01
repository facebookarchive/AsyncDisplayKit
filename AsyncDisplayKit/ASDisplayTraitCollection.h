//
//  ASDisplayTraitCollection.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 3/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASTraitCollection.h>

@protocol ASTraitCollection;

typedef struct ASTraits {
  CGFloat displayScale;
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceIdiom userInterfaceIdiom;
  UIUserInterfaceSizeClass verticalSizeClass;
  UIForceTouchCapability forceTouchCapability;
} ASTraits;

@interface ASDisplayTraitCollection : NSObject <ASTraitCollection>

- (instancetype)initWithTraits:(ASTraits)traits;

- (UITraitCollection *)traitCollection;

@end