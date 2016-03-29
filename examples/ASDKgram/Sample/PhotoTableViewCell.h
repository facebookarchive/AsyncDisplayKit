//
//  PhotoTableViewCell.h
//  Flickrgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocation.h>
#import "PhotoModel.h"

@protocol PhotoTableViewCellProtocol <NSObject>
- (void)userProfileWasTouchedWithUser:(UserModel *)user;
- (void)photoLocationWasTouchedWithCoordinate:(CLLocationCoordinate2D)coordiantes name:(NSAttributedString *)name;
- (void)cellWasLongPressedWithPhoto:(PhotoModel *)photo;
- (void)photoLikesWasTouchedWithPhoto:(PhotoModel *)photo;
@end


@interface PhotoTableViewCell : UITableViewCell

@property (nonatomic, strong, readwrite) id<PhotoTableViewCellProtocol> delegate;

+ (CGFloat)heightForPhotoModel:(PhotoModel *)photo withWidth:(CGFloat)width;

- (void)updateCellWithPhotoObject:(PhotoModel *)photo;
- (void)loadCommentsForPhoto:(PhotoModel *)photo;

@end
