//
//  PhotoCollectionViewCell.h
//  ASDKgram
//
//  Created by Hannah Troisi on 3/2/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoModel.h"

@interface PhotoCollectionViewCell : UICollectionViewCell

- (void)updateCellWithPhotoObject:(PhotoModel *)photo;

@end
