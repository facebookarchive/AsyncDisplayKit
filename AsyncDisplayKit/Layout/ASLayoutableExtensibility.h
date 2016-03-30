//
//  ASLayoutableExtensibility.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 3/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ASLayoutableExtensibility <NSObject>

/// Currently up to 4 BOOL values
- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx;
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx;

/// Currently up to 1 NSInteger value
- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx;
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx;

/// Currently up to 1 UIEdgeInsets value
- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx;
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx;

@end
