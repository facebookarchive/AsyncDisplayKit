//
//  ASListKitTestAdapterDataSource.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <IGListKit/IGListKit.h>

@interface ASListKitTestAdapterDataSource : NSObject <IGListAdapterDataSource>

// array of numbers which is then passed to -[IGListTestSection setItems:]
@property (nonatomic, strong) NSArray <NSNumber *> *objects;

@end
