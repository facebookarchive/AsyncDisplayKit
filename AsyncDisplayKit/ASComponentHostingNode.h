//
//  ASComponentHostingNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if __has_include(<ComponentKit/ComponentKit.h>)

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <ComponentKit/CKUpdateMode.h>

@protocol CKComponentProvider;
@protocol CKComponentSizeRangeProviding;
@protocol ASComponentHostingNodeDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 @abstract An ASDisplayNode that renders a component from ComponentKit.
 */
@interface ASComponentHostingNode : ASDisplayNode

/**
 @abstract The Designated initializer.
 */
- (instancetype)initWithComponentProvider:(Class<CKComponentProvider>)componentProvider
                        sizeRangeProvider:(id<CKComponentSizeRangeProviding>)sizeRangeProvider;

/**
 @abstract Updates the model used to render the component. This is thread-safe.
 */
- (void)updateModel:(nullable id<NSObject>)model mode:(CKUpdateMode)mode;

/**
 @abstract Updates the context used to render the component. This is thread-safe.
 */
- (void)updateContext:(nullable id<NSObject>)context mode:(CKUpdateMode)mode;

/**
 @abstract Notified when the node's ideal size (measured by -calculateSizeThatFits:) may have changed.
 */
@property (nonatomic, nullable, weak) id<ASComponentHostingNodeDelegate> delegate;

@end

@protocol ASComponentHostingNodeDelegate <NSObject>

/**
 @abstract Called after the hosting node updates the component view to a new size.
 @discussion The delegate can use this callback to appropriately resize the node frame to fit
 the new component size. The node will not resize itself.
 */
- (void)componentHostingNodeDidInvalidateSize:(ASComponentHostingNode *)hostingNode;

@end

NS_ASSUME_NONNULL_END

#endif
