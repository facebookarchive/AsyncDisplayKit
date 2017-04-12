//
//  ASTipProvider.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode, ASTip;

NS_ASSUME_NONNULL_BEGIN

/**
 * An abstract superclass for all tip providers.
 */
@interface ASTipProvider : NSObject

/**
 * The provider looks at the node's current situation and
 * generates a tip, if any, to add to the node.
 *
 * Subclasses must override this.
 */
- (nullable ASTip *)tipForNode:(ASDisplayNode *)node;

@end

@interface ASTipProvider (Lookup)

@property (class, nonatomic, copy, readonly) NSArray<__kindof ASTipProvider *> *all;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
