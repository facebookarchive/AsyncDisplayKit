//
//  ASCellNodeInternal.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 10/9/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASCellNodeInternal.h"

@implementation ASCellNode (Internal)

// FIXME: Is locking this worth the extra lock?

- (BOOL)needsMeasure
{
  return _needsMeasure;
}

- (void)setNeedsMeasure:(BOOL)needsMeasure
{
  _needsMeasure = needsMeasure;
}

@end
