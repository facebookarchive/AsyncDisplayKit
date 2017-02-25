//
//  ASSection.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/08/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/ASSectionContext.h>

@implementation ASSection

- (instancetype)initWithSectionID:(NSInteger)sectionID context:(id<ASSectionContext>)context
{
  self = [super init];
  if (self) {
    _sectionID = sectionID;
    _context = context;
  }
  return self;
}

@end
