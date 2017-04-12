//
//  ASTip.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTip.h"

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASDisplayNode.h>

@implementation ASTip

- (instancetype)initWithNode:(ASDisplayNode *)node
                        kind:(ASTipKind)kind
                      format:(NSString *)format, ...
{
  if (self = [super init]) {
    _node = node;
    _kind = kind;
    va_list args;
    va_start(args, format);
    _text = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  }
  return self;
}

@end

#endif // AS_ENABLE_TIPS
