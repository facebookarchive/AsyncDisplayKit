//
//  ASDefaultPlaybackButton.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/14/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
typedef enum {
  ASDefaultPlaybackButtonTypePlay,
  ASDefaultPlaybackButtonTypePause
} ASDefaultPlaybackButtonType;
@interface ASDefaultPlaybackButton : ASControlNode
@property (nonatomic, assign) ASDefaultPlaybackButtonType buttonType;
@end
