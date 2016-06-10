//
//  CommentModel.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/9/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "CommentModel.h"
#import "Utilities.h"

@implementation CommentModel
{
  NSDictionary *_dictionaryRepresentation;
  NSString     *_uploadDateRaw;
}

#pragma mark - Lifecycle

- (instancetype)initWithDictionary:(NSDictionary *)photoDictionary
{
  self = [super init];
  
  if (self) {
    _dictionaryRepresentation = photoDictionary;
    _ID                       = [[photoDictionary objectForKey:@"id"] integerValue];
    _commenterID              = [[photoDictionary objectForKey:@"user_id"] integerValue];
    _commenterUsername        = [photoDictionary valueForKeyPath:@"user.username"];
    _commenterAvatarURL       = [photoDictionary valueForKeyPath:@"user.userpic_url"];
    _body                     = [photoDictionary objectForKey:@"body"];
    _uploadDateRaw            = [photoDictionary valueForKeyPath:@"created_at"];
    _uploadDateString         = [NSString elapsedTimeStringSinceDate:_uploadDateRaw];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSAttributedString *)commentAttributedString
{
  NSString *commentString = [NSString stringWithFormat:@"%@ %@",[_commenterUsername lowercaseString], _body];
  return [NSAttributedString attributedStringWithString:commentString fontSize:14 color:[UIColor darkGrayColor] firstWordColor:[UIColor darkBlueColor]];
}

- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;
{
  return [NSAttributedString attributedStringWithString:self.uploadDateString fontSize:size color:[UIColor lightGrayColor] firstWordColor:nil];
}

@end
