//
//  ASNodeController.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi for Scott Goodson on 1/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h> // for ASInterfaceState protocol

/* ASNodeController is currently beta and open to change in the future */
@interface ASNodeController<__covariant DisplayNodeType : ASDisplayNode *> : NSObject <ASInterfaceStateDelegate>

@property (nonatomic, strong) DisplayNodeType node;

- (void)loadNode;

// for descriptions see <ASInterfaceState> definition
- (void)didEnterVisibleState ASDISPLAYNODE_REQUIRES_SUPER;
- (void)didExitVisibleState  ASDISPLAYNODE_REQUIRES_SUPER;

- (void)didEnterDisplayState ASDISPLAYNODE_REQUIRES_SUPER;
- (void)didExitDisplayState  ASDISPLAYNODE_REQUIRES_SUPER;

- (void)didEnterPreloadState ASDISPLAYNODE_REQUIRES_SUPER;
- (void)didExitPreloadState  ASDISPLAYNODE_REQUIRES_SUPER;

- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState ASDISPLAYNODE_REQUIRES_SUPER;

@end
