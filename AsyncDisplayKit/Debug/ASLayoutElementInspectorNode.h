//
//  ASLayoutElementInspectorNode.h
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

@protocol ASLayoutElement;

@protocol ASLayoutElementInspectorNodeDelegate <NSObject>

- (void)toggleVisualization:(BOOL)toggle;

@end

@interface ASLayoutElementInspectorNode : ASDisplayNode

@property (nonatomic, strong) id<ASLayoutElement>                      layoutElementToEdit;
@property (nonatomic, strong) id<ASLayoutElementInspectorNodeDelegate> delegate;
@property (nonatomic, assign) CGFloat                               vizNodeInsetSize;

+ (instancetype)sharedInstance;

@end
