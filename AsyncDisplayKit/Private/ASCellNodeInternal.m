//
//  ASCellNodeInternal.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 10/9/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASCellNodeInternal.h"

@implementation ASCellNode (Internal)

// FIXME: Lock this

- (BOOL)needsMeasure
{
  return _needsMeasure;
}

- (void)setNeedsMeasure:(BOOL)needsMeasure
{
  _needsMeasure = needsMeasure;
}

@end
