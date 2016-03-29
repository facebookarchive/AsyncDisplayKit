//
//  PhotoCellNode.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocation.h>
#import "PhotoModel.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "PhotoTableViewCell.h"   // PhotoTableViewCellProtocol


@interface PhotoCellNode : ASCellNode

@property (nonatomic, strong, readwrite) id<PhotoTableViewCellProtocol> delegate;

- (instancetype)initWithPhotoObject:(PhotoModel *)photo;
- (void)loadCommentsForPhoto:(PhotoModel *)photo;

@end
