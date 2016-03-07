//
//  AsyncDisplayKit+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASImageNode.h"

@interface ASImageNode (Debug)

/**
* Class method to enable visualization of an ASImageNode's image size. For app debugging purposes only.
* @param enabled Specify YES to turn on this debug feature when messaging the ASImageNode class.
*/
+ (void)setImageDebugEnabled:(BOOL)enable;
+ (BOOL)shouldShowImageDebugOverlay;

@end