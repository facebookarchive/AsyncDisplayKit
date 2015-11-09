//
//  ASTableNode.h
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode

- (instancetype)initWithStyle:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) ASTableView *view;

@end
