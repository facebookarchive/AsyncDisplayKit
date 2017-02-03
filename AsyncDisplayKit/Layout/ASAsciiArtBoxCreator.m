//
//  ASAsciiArtBoxCreator.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>

#import <CoreGraphics/CoreGraphics.h>
#import <tgmath.h>

static const NSUInteger kDebugBoxPadding = 2;

typedef NS_ENUM(NSUInteger, PIDebugBoxPaddingLocation)
{
  PIDebugBoxPaddingLocationFront,
  PIDebugBoxPaddingLocationEnd,
  PIDebugBoxPaddingLocationBoth
};

@interface NSString(PIDebugBox)

@end

@implementation NSString(PIDebugBox)

+ (instancetype)debugbox_stringWithString:(NSString *)stringToRepeat repeatedCount:(NSUInteger)repeatCount
{
  NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[stringToRepeat length]  * repeatCount];
  for (NSUInteger index = 0; index < repeatCount; index++) {
    [string appendString:stringToRepeat];
  }
  return [string copy];
}

- (NSString *)debugbox_stringByAddingPadding:(NSString *)padding count:(NSUInteger)count location:(PIDebugBoxPaddingLocation)location
{
  NSString *paddingString = [NSString debugbox_stringWithString:padding repeatedCount:count];
  switch (location) {
    case PIDebugBoxPaddingLocationFront:
      return [NSString stringWithFormat:@"%@%@", paddingString, self];
    case PIDebugBoxPaddingLocationEnd:
      return [NSString stringWithFormat:@"%@%@", self, paddingString];
    case PIDebugBoxPaddingLocationBoth:
      return [NSString stringWithFormat:@"%@%@%@", paddingString, self, paddingString];
  }
  return [self copy];
}

@end

@implementation ASAsciiArtBoxCreator

+ (NSString *)horizontalBoxStringForChildren:(NSArray *)children parent:(NSString *)parent
{
  if ([children count] == 0) {
    return parent;
  }
  
  NSMutableArray *childrenLines = [NSMutableArray array];
  
  // split the children into lines
  NSUInteger lineCountPerChild = 0;
  for (NSString *child in children) {
    NSArray *lines = [child componentsSeparatedByString:@"\n"];
    lineCountPerChild = MAX(lineCountPerChild, [lines count]);
  }
  
  for (NSString *child in children) {
    NSMutableArray *lines = [[child componentsSeparatedByString:@"\n"] mutableCopy];
    NSUInteger topPadding = ceil((CGFloat)(lineCountPerChild - [lines count])/2.0);
    NSUInteger bottomPadding = (lineCountPerChild - [lines count])/2.0;
    NSUInteger lineLength = [lines[0] length];
    
    for (NSUInteger index = 0; index < topPadding; index++) {
      [lines insertObject:[NSString debugbox_stringWithString:@" " repeatedCount:lineLength] atIndex:0];
    }
    for (NSUInteger index = 0; index < bottomPadding; index++) {
      [lines addObject:[NSString debugbox_stringWithString:@" " repeatedCount:lineLength]];
    }
    [childrenLines addObject:lines];
  }
  
  NSMutableArray *concatenatedLines = [NSMutableArray array];
  NSString *padding = [NSString debugbox_stringWithString:@" " repeatedCount:kDebugBoxPadding];
  for (NSUInteger index = 0; index < lineCountPerChild; index++) {
    NSMutableString *line = [[NSMutableString alloc] init];
    [line appendFormat:@"|%@",padding];
    for (NSArray *childLines in childrenLines) {
      [line appendFormat:@"%@%@", childLines[index], padding];
    }
    [line appendString:@"|"];
    [concatenatedLines addObject:line];
  }
  
  // surround the lines in a box
  NSUInteger totalLineLength = [concatenatedLines[0] length];
  if (totalLineLength < [parent length]) {
    NSUInteger difference = [parent length] + (2 * kDebugBoxPadding) - totalLineLength;
    NSUInteger leftPadding = ceil((CGFloat)difference/2.0);
    NSUInteger rightPadding = difference/2;
    
    NSString *leftString = [@"|" debugbox_stringByAddingPadding:@" " count:leftPadding location:PIDebugBoxPaddingLocationEnd];
    NSString *rightString = [@"|" debugbox_stringByAddingPadding:@" " count:rightPadding location:PIDebugBoxPaddingLocationFront];
    
    NSMutableArray *paddedLines = [NSMutableArray array];
    for (NSString *line in concatenatedLines) {
      NSString *paddedLine = [line stringByReplacingOccurrencesOfString:@"|" withString:leftString options:NSCaseInsensitiveSearch range:NSMakeRange(0, 1)];
      paddedLine = [paddedLine stringByReplacingOccurrencesOfString:@"|" withString:rightString options:NSCaseInsensitiveSearch range:NSMakeRange([paddedLine length] - 1, 1)];
      [paddedLines addObject:paddedLine];
    }
    concatenatedLines = paddedLines;
    // totalLineLength += difference;
  }
  concatenatedLines = [self appendTopAndBottomToBoxString:concatenatedLines parent:parent];
  return [concatenatedLines componentsJoinedByString:@"\n"];
  
}

+ (NSString *)verticalBoxStringForChildren:(NSArray *)children parent:(NSString *)parent
{
  if ([children count] == 0) {
    return parent;
  }
  
  NSMutableArray *childrenLines = [NSMutableArray array];
  
  NSUInteger maxChildLength = 0;
  for (NSString *child in children) {
    NSArray *lines = [child componentsSeparatedByString:@"\n"];
    maxChildLength = MAX(maxChildLength, [lines[0] length]);
  }
  
  NSUInteger rightPadding = 0;
  NSUInteger leftPadding = 0;
  
  if (maxChildLength < [parent length]) {
    NSUInteger difference = [parent length] + (2 * kDebugBoxPadding) - maxChildLength;
    leftPadding = ceil((CGFloat)difference/2.0);
    rightPadding = difference/2;
  }
  
  NSString *rightPaddingString = [NSString debugbox_stringWithString:@" " repeatedCount:rightPadding + kDebugBoxPadding];
  NSString *leftPaddingString = [NSString debugbox_stringWithString:@" " repeatedCount:leftPadding + kDebugBoxPadding];
  
  for (NSString *child in children) {
    NSMutableArray *lines = [[child componentsSeparatedByString:@"\n"] mutableCopy];
    
    NSUInteger leftLinePadding = ceil((CGFloat)(maxChildLength - [lines[0] length])/2.0);
    NSUInteger rightLinePadding = (maxChildLength - [lines[0] length])/2.0;
    
    for (NSString *line in lines) {
      NSString *rightLinePaddingString = [NSString debugbox_stringWithString:@" " repeatedCount:rightLinePadding];
      rightLinePaddingString = [NSString stringWithFormat:@"%@%@|", rightLinePaddingString, rightPaddingString];
      
      NSString *leftLinePaddingString = [NSString debugbox_stringWithString:@" " repeatedCount:leftLinePadding];
      leftLinePaddingString = [NSString stringWithFormat:@"|%@%@", leftLinePaddingString, leftPaddingString];
      
      NSString *paddingLine = [NSString stringWithFormat:@"%@%@%@", leftLinePaddingString, line, rightLinePaddingString];
      [childrenLines addObject:paddingLine];
    }
  }
  
  childrenLines = [self appendTopAndBottomToBoxString:childrenLines parent:parent];
  return [childrenLines componentsJoinedByString:@"\n"];
}

+ (NSMutableArray *)appendTopAndBottomToBoxString:(NSMutableArray *)boxStrings parent:(NSString *)parent
{
  NSUInteger totalLineLength = [boxStrings[0] length];
  [boxStrings addObject:[NSString debugbox_stringWithString:@"-" repeatedCount:totalLineLength]];
  
  NSUInteger leftPadding = ceil(((CGFloat)(totalLineLength - [parent length]))/2.0);
  NSUInteger rightPadding = (totalLineLength - [parent length])/2;
  
  NSString *topLine = [parent debugbox_stringByAddingPadding:@"-" count:leftPadding location:PIDebugBoxPaddingLocationFront];
  topLine = [topLine debugbox_stringByAddingPadding:@"-" count:rightPadding location:PIDebugBoxPaddingLocationEnd];
  [boxStrings insertObject:topLine atIndex:0];
  
  return boxStrings;
}

@end
