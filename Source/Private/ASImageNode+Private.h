//
//  ASImageNode+Private.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 3/20/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#pragma once

@interface ASImageNode (Private)

- (void)_locked_setImage:(UIImage *)image;
- (UIImage *)_locked_Image;

@end
