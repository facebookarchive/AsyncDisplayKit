//
//  PhotoFeedModel.m
//  Sample
//
//  Created by Hannah Troisi on 2/28/16.
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

#import "PhotoFeedModel.h"
#import "ImageURLModel.h"

#define fiveHundredPX_ENDPOINT_HOST      @"https://api.500px.com/v1/"
#define fiveHundredPX_ENDPOINT_POPULAR   @"photos?feature=popular&exclude=Nude,People,Fashion&sort=rating&image_size=3&include_store=store_download&include_states=voted"
#define fiveHundredPX_ENDPOINT_SEARCH    @"photos/search?geo="    //latitude,longitude,radius<units>
#define fiveHundredPX_ENDPOINT_USER      @"photos?user_id="
#define fiveHundredPX_CONSUMER_KEY_PARAM @"&consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC"   // PLEASE REQUEST YOUR OWN 500PX CONSUMER KEY

@implementation PhotoFeedModel
{
  PhotoFeedModelType _feedType;
  
  NSMutableArray *_photos;    // array of PhotoModel objects
  NSMutableArray *_ids;
  
  CGSize         _imageSize;
  NSString       *_urlString;
  NSUInteger     _currentPage;
  NSUInteger     _totalPages;
  NSUInteger     _totalItems;
  BOOL           _fetchPageInProgress;
  BOOL           _refreshFeedInProgress;
  NSURLSessionDataTask *_task;

  CLLocationCoordinate2D _location;
  NSUInteger    _locationRadius;
  NSUInteger    _userID;
}

#pragma mark - Properties

- (NSMutableArray *)photos
{
  return _photos;
}

#pragma mark - Lifecycle

- (instancetype)initWithPhotoFeedModelType:(PhotoFeedModelType)type imageSize:(CGSize)size
{
  self = [super init];
  
  if (self) {
    _feedType    = type;
    _imageSize   = size;
    _photos      = [[NSMutableArray alloc] init];
    _ids         = [[NSMutableArray alloc] init];
    _currentPage = 0;
    
    NSString *apiEndpointString;
    switch (type) {
      case (PhotoFeedModelTypePopular):
        apiEndpointString = fiveHundredPX_ENDPOINT_POPULAR;
        break;
        
      case (PhotoFeedModelTypeLocation):
        apiEndpointString = fiveHundredPX_ENDPOINT_SEARCH;
        break;
        
      case (PhotoFeedModelTypeUserPhotos):
        apiEndpointString = fiveHundredPX_ENDPOINT_USER;
        break;
        
      default:
        break;
    }
    _urlString = [[fiveHundredPX_ENDPOINT_HOST stringByAppendingString:apiEndpointString] stringByAppendingString:fiveHundredPX_CONSUMER_KEY_PARAM];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSUInteger)totalNumberOfPhotos
{
  return _totalItems;
}

- (NSUInteger)numberOfItemsInFeed
{
  return [_photos count];
}

- (PhotoModel *)objectAtIndex:(NSUInteger)index
{
  return [_photos objectAtIndex:index];
}

- (NSInteger)indexOfPhotoModel:(PhotoModel *)photoModel
{
  return [_photos indexOfObjectIdenticalTo:photoModel];
}

- (void)updatePhotoFeedModelTypeLocationCoordinates:(CLLocationCoordinate2D)coordinate radiusInMiles:(NSUInteger)radius;
{
  _location = coordinate;
  _locationRadius = radius;
  NSString *locationString = [NSString stringWithFormat:@"%f,%f,%lumi", coordinate.latitude, coordinate.longitude, (unsigned long)radius];
  
  _urlString = [fiveHundredPX_ENDPOINT_HOST stringByAppendingString:fiveHundredPX_ENDPOINT_SEARCH];
  _urlString = [[_urlString stringByAppendingString:locationString] stringByAppendingString:fiveHundredPX_CONSUMER_KEY_PARAM];
}

- (void)updatePhotoFeedModelTypeUserId:(NSUInteger)userID
{
  _userID = userID;
  
  NSString *userString = [NSString stringWithFormat:@"%lu", (long)userID];
  _urlString = [fiveHundredPX_ENDPOINT_HOST stringByAppendingString:fiveHundredPX_ENDPOINT_USER];
  _urlString = [[_urlString stringByAppendingString:userString] stringByAppendingString:@"&sort=created_at&image_size=3&include_store=store_download&include_states=voted"];
  _urlString = [_urlString stringByAppendingString:fiveHundredPX_CONSUMER_KEY_PARAM];
}

- (void)clearFeed
{
  _photos = [[NSMutableArray alloc] init];
  _ids = [[NSMutableArray alloc] init];
  _currentPage = 0;
  _fetchPageInProgress = NO;
  _refreshFeedInProgress = NO;
  [_task cancel];
  _task = nil;
}

- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  // only one fetch at a time
  if (_fetchPageInProgress) {
    return;
  } else {
    _fetchPageInProgress = YES;
    [self fetchPageWithCompletionBlock:block numResultsToReturn:numResults];
  }
}

- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  // only one fetch at a time
  if (_refreshFeedInProgress) {
    return;
    
  } else {
    _refreshFeedInProgress = YES;
    _currentPage = 0;
    
    // FIXME: blow away any other requests in progress
    [self fetchPageWithCompletionBlock:^(NSArray *newPhotos) {
      if (block) {
        block(newPhotos);
      }
      _refreshFeedInProgress = NO;
    } numResultsToReturn:numResults replaceData:YES];
  }
}

#pragma mark - Helper Methods

- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  [self fetchPageWithCompletionBlock:block numResultsToReturn:numResults replaceData:NO];
}

- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults replaceData:(BOOL)replaceData
{
  // early return if reached end of pages
  if (_totalPages) {
    if (_currentPage == _totalPages) {
      return;
    }
  }
  
  NSUInteger numPhotos = (numResults < 100) ? numResults : 100;
    
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSMutableArray *newPhotos = [NSMutableArray array];
    NSMutableArray *newIDs = [NSMutableArray array];
    
    @synchronized(self) {
      NSUInteger nextPage      = _currentPage + 1;
      NSString *imageSizeParam = [ImageURLModel imageParameterForClosestImageSize:_imageSize];
      NSString *urlAdditions   = [NSString stringWithFormat:@"&page=%lu&rpp=%lu%@", (unsigned long)nextPage, (long)numPhotos, imageSizeParam];
      NSURL *url               = [NSURL URLWithString:[_urlString stringByAppendingString:urlAdditions]];
      NSURLSession *session    = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
      _task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data) {
          NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
          
          if ([response isKindOfClass:[NSDictionary class]]) {
            _currentPage = [[response valueForKeyPath:@"current_page"] integerValue];
            _totalPages  = [[response valueForKeyPath:@"total_pages"] integerValue];
            _totalItems  = [[response valueForKeyPath:@"total_items"] integerValue];
            
            NSArray *photos = [response valueForKeyPath:@"photos"];
            if ([photos isKindOfClass:[NSArray class]]) {
              for (NSDictionary *photoDictionary in photos) {
                if ([response isKindOfClass:[NSDictionary class]]) {
                  PhotoModel *photo = [[PhotoModel alloc] initWith500pxPhoto:photoDictionary];
                  if (photo) {
                    if (replaceData || ![_ids containsObject:photo.photoID]) {
                      [newPhotos addObject:photo];
                      [newIDs addObject:photo.photoID];
                    }
                  }
                }
              }
            }
          }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          if (replaceData) {
            _photos = [newPhotos mutableCopy];
            _ids = [newIDs mutableCopy];
          } else {
            [_photos addObjectsFromArray:newPhotos];
            [_ids addObjectsFromArray:newIDs];
          }
          if (block) {
            block(newPhotos);
          }
          _fetchPageInProgress = NO;
        });
      }];
      [_task resume];
    }
  });
}

@end
