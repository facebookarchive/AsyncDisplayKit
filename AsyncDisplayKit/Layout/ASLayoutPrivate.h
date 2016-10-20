//
//  ASLayoutPrivate.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 10/17/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#pragma once

#import "ASLayout.h"

/**
 * Private header of ASLayout for internal usage in the framework
 */
@interface ASLayout ()

/**
 * Position in parent. Default to CGPointNull.
 *
 * @discussion When being used as a sublayout, this property must not equal CGPointNull.
 */
@property (nonatomic, assign, readwrite) CGPoint position;

@end
