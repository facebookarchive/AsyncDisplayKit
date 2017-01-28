//
//  ASNodeController.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi for Scott Goodson on 1/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

@interface ASNodeController<__covariant DisplayNodeType : ASDisplayNode *> : NSObject

@property (nonatomic, strong) DisplayNodeType node;

- (void)loadNode;

@end
