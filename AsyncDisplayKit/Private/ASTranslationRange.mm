//
//  ASTranslationRange.mm
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 4/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASTranslationRange.h"

#import "ASAssert.h"
#import "ASThread.h"
#import <vector>
#import <algorithm>

@interface ASTranslationRange () {
  NSUInteger _length;
  std::vector<NSRange> _ranges;
  ASDN::RecursiveMutex _propertyLock;
}

@end

@implementation ASTranslationRange

- (instancetype)initWithLocation:(NSUInteger)location length:(NSUInteger)length
{
  ASDisplayNodeAssert(location >= 0, @"Location must be greater than or equal to 0");
  ASDisplayNodeAssert(length >= 1, @"Length must be greater than 1");

  self = [super init];
  if (self != nil) {
    _location = location;
    _length = length;
    _ranges = { NSMakeRange(location, length) };
  }
  return self;
}

- (NSUInteger)location
{
  ASDN::MutexLocker l(_propertyLock);
  return _location;
}

- (void)setLocation:(NSUInteger)location
{
  ASDN::MutexLocker l(_propertyLock);
  _location = location;
  // TODO(levi): Increment/decrement the location of all ranges
}

- (NSUInteger)length
{
  ASDN::MutexLocker l(_propertyLock);
  return _length;
}

- (void)insertOffsetAtIndex:(NSUInteger)index
{
  ASDN::MutexLocker l(_propertyLock);
  // noop if out of the range
  if (index <= _location || index > _length - 1) {
    return;
  }
  
  BOOL splitRange = NO;
  NSInteger offsetIndex;
  for (offsetIndex = 0; offsetIndex < _ranges.size(); offsetIndex++) {
    NSRange range = _ranges[offsetIndex];
    // When the index intersects, queue the intersecting range to be split at the index
    if (NSLocationInRange(index, range)) {
      splitRange = YES;
      break;
    // When the index is between the previous and current range, queue all other range locations to be incremented
    } else if (index < range.location) {
      break;
    }
  }
  
  if (splitRange) {
    NSRange splitRange = _ranges[offsetIndex];
    NSUInteger splitLength = index - splitRange.location;
    _ranges[offsetIndex] = NSMakeRange(splitRange.location, splitLength);
    _ranges.insert(_ranges.begin() + offsetIndex, NSMakeRange((splitLength + splitRange.location) + 1, splitRange.length - splitLength));
  }
  
  for (NSUInteger i = offsetIndex; i < _ranges.size(); i++) {
    _ranges[i] = NSMakeRange(_ranges[i].location + 1, _ranges[i].length);
  }
}

- (void)removeOffsetAtIndex:(NSUInteger)index
{
  NSInteger intersectingRange = -1;
  for (NSUInteger i = 0; i < _ranges.size(); i++) {
    NSRange range = _ranges[index];
    // No-op when trying to remove an offset that doesn't exist
    if (NSLocationInRange(index, range)) {
      return;
    } else if (range.location < index) {
      break;
    }
  }
  
  // if the previous range is only separated by one, remove the current one and increase the length of the previous
  // one by the length of the current one
  
  // iterate through the remaining ranges, decrementing the location of the range
}

- (NSUInteger)translatedIndex:(NSUInteger)index
{
  NSUInteger translatedIndex = NSNotFound;
  for (NSUInteger i = 0; i < _ranges.size(); i++) {
    NSRange range = _ranges[i];
    translatedIndex = range.location;
    if (NSLocationInRange(index, range)) {
      translatedIndex += index - range.location;
    }
  }
  return translatedIndex;
}

@end
