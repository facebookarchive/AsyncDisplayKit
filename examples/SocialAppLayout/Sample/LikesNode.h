//
//  LikesNode.h
//  Sample
//
//  Created by Vitaly Baev on 06.11.15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LikesNode : ASControlNode {
    
    ASImageNode *_iconNode;
    ASTextNode *_countNode;
    
    NSInteger _likesCount;
    BOOL _liked;
    
}

- (instancetype)initWithLikesCount:(NSInteger)likesCount;

+ (BOOL) getYesOrNo;

@end
