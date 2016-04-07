//
//  ASTranslationRange.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 4/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A translation range simulates a contiguous range, but allows offsets to be inserted and removed to translate an index
 * within the contiguous range to the actual index that
 */
@interface ASTranslationRange : NSObject

/**
 * The starting point of the range
 */
@property (nonatomic, assign) NSUInteger location;

/**
 * Designated initializer
 */
- (instancetype)initWithLocation:(NSUInteger)location length:(NSUInteger)length;

/**
 * The length of the range
 */
- (NSUInteger)length;

/**
 * Inserts a new offset point in the range at the given index
 */
- (void)insertOffsetAtLocation:(NSUInteger)location;

/**
 * Removes an offset in the range at the given index
 */
- (void)removeOffsetAtLocation:(NSUInteger)location;

/**
 * Returns an index offset via the current intersections in the range
 */
- (NSUInteger)translatedLocation:(NSUInteger)location;

@end
