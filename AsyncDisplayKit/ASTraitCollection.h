//
//  ASTraitCollection.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 3/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

@protocol ASTraitCollection <NSObject>

@property(nonatomic, readonly) CGFloat displayScale;
@property(nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property(nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property(nonatomic, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@property(nonatomic, readonly) UIForceTouchCapability forceTouchCapability;

- (BOOL)containsTraitsInCollection:(id<ASTraitCollection>)trait;

@end