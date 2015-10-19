//
//  ASChangeSetDataController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 19/10/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDataController.h>

/**
 * Subclass of ASDataController that enqueues and sorts edit commands during batch updating (using _ASHierarchyChangeSet).
 *
 * @see ASDataController
 * @see _ASHierarchyChangeSet
 */
@interface ASChangeSetDataController : ASDataController

@end
