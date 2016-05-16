//
//  VideoContentCell.h
//  Sample
//
//  Created by Erekle on 5/14/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "VideoModel.h"

@interface VideoContentCell : ASCellNode
- (instancetype)initWithVideoObject:(VideoModel *)video;
@end
