//
//  TextNode.h
//  Sample
//
//  Created by Nikita Ivanchikov on 12/8/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface TextNode : ASCellNode

- (instancetype)initWithString:(NSString *)string verticalTextAlignment: (ASTextNodeVerticalTextAlignment) verticalAlignment;

@end
