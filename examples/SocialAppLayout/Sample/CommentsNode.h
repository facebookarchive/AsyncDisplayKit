//
//  CommentsNode.h
//  Sample
//
//  Created by Vitaly Baev on 06.11.15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface CommentsNode : ASControlNode {
    
    ASImageNode *_iconNode;
    ASTextNode *_countNode;
    
    NSInteger _comentsCount;
    
}

- (instancetype)initWithCommentsCount:(NSInteger)comentsCount;

@end
