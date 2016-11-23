//
//  ASDisplayNodeController+Subclasses.h
//  AsyncDisplayKit
//
//  Created by Bussiere, Mathieu on 2015-11-26.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNodeController.h>
#import <AsyncDisplayKit/ASDisplayNodeContainerDelegate.h>

@interface ASDisplayNodeController (Subclasses)

- (void)recursivelySetContainerDelegate:(id<ASDisplayNodeContainerDelegate>)containerDelegate;

@end