//
//  Component.m
//  Sample
//
//  Created by Gautham Badhrinathan on 8/23/16.
//  Copyright © 2016 Facebook Inc. All rights reserved.
//

#if __has_include(<ComponentKit/ComponentKit.h>)

#import <Foundation/Foundation.h>
#import <ComponentKit/CKComponentSubclass.h>

#import "Component.h"

@implementation Component

+ (NSNumber *)initialState
{
  return @NO;
}

+ (instancetype)new
{
  CKComponentScope scope(self);
  NSNumber *state = scope.state();

  return
  [super
   newWithView:{
     [UIView class],
     {
       {@selector(setUserInteractionEnabled:), @YES},
       {@selector(setBackgroundColor:), state.boolValue ? [UIColor redColor] : [UIColor cyanColor]},
       CKComponentTapGestureAttribute(@selector(_didTapOnSelf)),
     }
   }
   size:{
     state.boolValue ? 200 : 100,
     state.boolValue ? 200 : 100,
   }];
}

- (void)_didTapOnSelf
{
  [self updateState:^(NSNumber *state) {
    return @(!state.boolValue);
  } mode:CKUpdateModeAsynchronous];
}

@end

#endif
