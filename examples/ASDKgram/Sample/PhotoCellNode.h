//
//  PhotoCellNode.h
//  Flickrgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <CoreLocation/CLLocation.h>
#import "PhotoModel.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "PhotoTableViewCell.h"   // PhotoTableViewCellProtocol


@interface PhotoCellNode : ASCellNode

- (instancetype)initWithPhotoObject:(PhotoModel *)photo;

@end
