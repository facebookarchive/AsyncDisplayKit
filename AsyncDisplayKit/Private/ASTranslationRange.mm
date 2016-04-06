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

@synthesize location = _location;

- (instancetype)initWithLocation:(NSUInteger)location length:(NSUInteger)length
{
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
  if (location != _location) {
    NSInteger delta = location - _location;
    _location = location;
    
    // Shift the location of all the inner ranges by the delta
    for (NSUInteger i = 0; i < _ranges.size(); i++) {
      NSRange range = _ranges[i];
      _ranges[i] = NSMakeRange(range.location + delta, range.length);
    }
  }
}

- (NSUInteger)length
{
  ASDN::MutexLocker l(_propertyLock);
  return _length;
}

- (void)insertOffsetAtLocation:(NSUInteger)location
{
  ASDN::MutexLocker l(_propertyLock);
  // noop if out of the range
  if (location <= _location || location > _length - 1) {
    return;
  }
  
  BOOL splitRange = NO;
  NSInteger offsetIndex;
  for (offsetIndex = 0; offsetIndex < _ranges.size(); offsetIndex++) {
    NSRange range = _ranges[offsetIndex];
    // When the index intersects, queue the intersecting range to be split at the index
    if (NSLocationInRange(location, range)) {
      splitRange = YES;
      break;
    // When the location is between the previous and current range, queue all other range locations to be incremented
    } else if (location < range.location) {
      break;
    }
  }
  
  if (splitRange) {
    NSRange range = _ranges[offsetIndex];
    NSUInteger newLength = location - range.location;
    _ranges[offsetIndex] = NSMakeRange(range.location, newLength);
    _ranges.insert(_ranges.begin() + offsetIndex, NSMakeRange((newLength + range.location) + 1, range.length - newLength));
  }
  
  for (NSUInteger j = offsetIndex; j < _ranges.size(); j++) {
    _ranges[j] = NSMakeRange(_ranges[j].location + 1, _ranges[j].length);
  }
}

- (void)removeOffsetAtLocation:(NSUInteger)location
{
  NSInteger rightRangeIdx = NSNotFound;
  for (NSUInteger i = 0; i < _ranges.size(); i++) {
    NSRange range = _ranges[location];
    if (range.location < location) {
      rightRangeIdx = i;
      break;
    // No-op when trying to remove an offset that doesn't exist
    } else if (NSLocationInRange(location, range)) {
      return;
    }
  }
  
  if (rightRangeIdx == NSNotFound) {
    return;
  }
  
  NSUInteger leftRangeIdx = rightRangeIdx - 1;

  NSRange rightRange = _ranges[rightRangeIdx];
  NSRange leftRange = _ranges[leftRangeIdx];
  if (rightRange.location - (leftRange.location + leftRange.length) == 1) {
    // Merge the left and right range
    _ranges[leftRangeIdx] = NSMakeRange(leftRange.location, leftRange.length + rightRange.length);
    // Remove the right range
    _ranges.erase(_ranges.begin() + rightRangeIdx);
  }
  
  // iterate through the remaining ranges, decrementing the location of the range
  for (NSUInteger j = rightRangeIdx; j < _ranges.size(); j++) {
    NSRange range = _ranges[j];
    _ranges[j] = NSMakeRange(range.location - 1, range.length);
  }
}

- (NSUInteger)translatedLocation:(NSUInteger)location
{
  NSUInteger translatedIndex = NSNotFound;
  
  if (location < _location) {
    return translatedIndex;
  }

  NSUInteger indexOffset = 0;
  for (NSUInteger i = 0; i < _ranges.size(); i++) {
    NSRange range = _ranges[i];
    if (location <= indexOffset + range.length) {
      translatedIndex = range.location + (location - indexOffset);
      break;
    }
    indexOffset += range.length;
  }
  return translatedIndex;
}

@end
