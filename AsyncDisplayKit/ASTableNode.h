//
//  ASTableNode.h
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASTableView.h>

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode

- (instancetype)init; // UITableViewStylePlain
- (instancetype)initWithStyle:(UITableViewStyle)style;

@property (nonatomic, readonly) ASTableView *view;

// These properties can be set without triggering the view to be created, so it's fine to set them in -init.
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;

@end
