//
//  ASIndexedNodeContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASDimension.h>

@interface ASIndexedNodeContext : NSObject

@property (nonatomic, readonly, strong) ASCellNodeBlock nodeBlock;
@property (nonatomic, readonly, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly, assign) ASSizeRange constrainedSize;

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize;

@end
