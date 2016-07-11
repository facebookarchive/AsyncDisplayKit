//
//  ASDefaultPlaybackButton.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/14/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
typedef enum {
  ASDefaultPlaybackButtonTypePlay,
  ASDefaultPlaybackButtonTypePause
} ASDefaultPlaybackButtonType;
@interface ASDefaultPlaybackButton : ASControlNode
@property (nonatomic, assign) ASDefaultPlaybackButtonType buttonType;
@end
