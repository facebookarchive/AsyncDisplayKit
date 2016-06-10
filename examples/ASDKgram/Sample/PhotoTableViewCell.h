//
//  PhotoTableViewCell.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <CoreLocation/CLLocation.h>
#import "PhotoModel.h"

@interface PhotoTableViewCell : UITableViewCell

+ (CGFloat)heightForPhotoModel:(PhotoModel *)photo withWidth:(CGFloat)width;

- (void)updateCellWithPhotoObject:(PhotoModel *)photo;
- (void)loadCommentsForPhoto:(PhotoModel *)photo;

@end
