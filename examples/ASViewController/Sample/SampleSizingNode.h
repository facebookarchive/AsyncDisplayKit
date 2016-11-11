//
//  SampleSizingNode.h
//  Sample
//
//  Created by Michael Schneider on 11/10/16.
//  Copyright © 2016 AsyncDisplayKit. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

// ASDisplayNodeSizingDelegate / ASDisplayNodeSizingHandlers
@interface ASDisplayNodeSizingDelegate : NSObject
- (void)displayNodeDidInvalidateSize:(ASDisplayNode *)displayNode;
@end

@interface SampleSizingNode : ASDisplayNode
@property (nonatomic, weak) id delegate;
@end
