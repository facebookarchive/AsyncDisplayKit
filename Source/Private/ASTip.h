//
//  ASTip.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

NS_ASSUME_NONNULL_BEGIN

@class ASDisplayNode;

typedef NS_ENUM (NSInteger, ASTipKind) {
  ASTipKindEnableLayerBacking
};

AS_SUBCLASSING_RESTRICTED
@interface ASTip : NSObject

- (instancetype)initWithNode:(ASDisplayNode *)node
                        kind:(ASTipKind)kind
                      format:(NSString *)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 * The kind of tip this is.
 */
@property (nonatomic, readonly) ASTipKind kind;

/**
 * The node that this tip applies to.
 */
@property (nonatomic, strong, readonly) ASDisplayNode *node;

/**
 * The text to show the user.
 */
@property (nonatomic, strong, readonly) NSString *text;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
