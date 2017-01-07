//
//  PhotoModel.m
//  Sample
//
//  Created by Hannah Troisi on 2/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "PhotoModel.h"
#import "Utilities.h"

@implementation PhotoModel
{
  NSDictionary     *_dictionaryRepresentation;
  NSString         *_uploadDateRaw;
  CommentFeedModel *_commentFeed;
}

#pragma mark - Properties

- (CommentFeedModel *)commentFeed
{
  if (!_commentFeed) {
    _commentFeed = [[CommentFeedModel alloc] initWithPhotoID:_photoID];
  }
  
  return _commentFeed;
}

#pragma mark - Lifecycle

- (instancetype)initWith500pxPhoto:(NSDictionary *)photoDictionary
{
  self = [super init];
  
  if (self) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSString *samplePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SamplePhotoModel.plist"];
      NSDictionary *sampleModel = [NSDictionary dictionaryWithContentsOfFile:samplePath];
      if (sampleModel == nil) {
        // Have to use keyed archiver to support NSNull
        __unused BOOL success = [NSKeyedArchiver archiveRootObject:photoDictionary toFile:samplePath];
        NSAssert(success, @"Failed to write sample model.");
      }
    });
    _dictionaryRepresentation = photoDictionary;
    _uploadDateRaw            = [photoDictionary objectForKey:@"created_at"];
    _photoID                  = [[photoDictionary objectForKey:@"id"] description];
    _title                    = [photoDictionary objectForKey:@"title"];
    _descriptionText          = [photoDictionary valueForKeyPath:@"name"];
    _commentsCount            = [[photoDictionary objectForKey:@"comments_count"] integerValue];
    _likesCount               = [[photoDictionary objectForKey:@"positive_votes_count"] integerValue];
    
    NSString *urlString       = [photoDictionary objectForKey:@"image_url"];
    _URL                      = urlString ? [NSURL URLWithString:urlString] : nil;
    
    _location                 = [[LocationModel alloc] initWith500pxPhoto:photoDictionary];
    _ownerUserProfile         = [[UserModel alloc] initWith500pxPhoto:photoDictionary];
    _uploadDateString         = [NSString elapsedTimeStringSinceDate:_uploadDateRaw];
  }
  
  return self;
}

+ (instancetype)samplePhotoModel
{
  NSString *samplePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SamplePhotoModel.plist"];
  NSDictionary *sampleModel = [NSKeyedUnarchiver unarchiveObjectWithFile:samplePath];
  if (sampleModel == nil) {
    return nil;
  } else {
    return [[PhotoModel alloc] initWith500pxPhoto:sampleModel];
  }
}

#pragma mark - Instance Methods

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size
{
  NSString *string               = [NSString stringWithFormat:@"%@ %@", self.ownerUserProfile.username, self.descriptionText];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string
                                                                         fontSize:size
                                                                            color:[UIColor darkGrayColor]
                                                                   firstWordColor:[UIColor darkBlueColor]];
  return attrString;
}

- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.uploadDateString fontSize:size color:[UIColor lightGrayColor] firstWordColor:nil];
}

- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size
{
  NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
  [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
  NSString *formattedLikesNumber = [formatter stringFromNumber:[[NSNumber alloc] initWithUnsignedInteger:self.likesCount]];
  
  NSString *likesString = [NSString stringWithFormat:@"♥︎ %@ likes", formattedLikesNumber];

  return [NSAttributedString attributedStringWithString:likesString fontSize:size color:[UIColor darkBlueColor] firstWordColor:nil];
}

- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.location.locationString fontSize:size color:[UIColor lightBlueColor] firstWordColor:nil];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ - %@", _photoID, _descriptionText];
}

@end