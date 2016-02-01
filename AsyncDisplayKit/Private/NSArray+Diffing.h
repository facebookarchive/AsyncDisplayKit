//
//  NSArray+Diffing.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (Diffing)

/**
 * Uses a bottom-up memoized longest common subsequence solution to identify differences. Runs in O(mn) complexity.
 */
- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions;

@end
