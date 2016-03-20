//
//  EditorNode.h
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface EditorNode : ASDisplayNode

@property (nonatomic, strong) id<ASLayoutable> layoutableToEdit;

@end
