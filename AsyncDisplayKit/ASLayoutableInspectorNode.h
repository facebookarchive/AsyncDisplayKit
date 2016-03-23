//
//  ASLayoutableInspectorNode.h
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@protocol ASLayoutableInspectorNodeDelegate <NSObject>

- (void)shouldShowMasterSplitViewController;

@end 


@interface ASLayoutableInspectorNode : ASDisplayNode <UISplitViewControllerDelegate>

@property (nonatomic, strong) id<ASLayoutable> layoutableToEdit;
@property (nonatomic, strong) id<ASLayoutableInspectorNodeDelegate> delegate;

+ (instancetype)sharedInstance;

@end
