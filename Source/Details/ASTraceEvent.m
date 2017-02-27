//
//  ASTraceEvent.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/13/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASTraceEvent.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const ASTraceEventThreadDescriptionKey = @"ASThreadTraceEventDescription";

@interface ASTraceEvent ()
@property (nonatomic, strong, readonly) NSString *objectDescription;
@property (nonatomic, strong, readonly) NSString *threadDescription;
@end

@implementation ASTraceEvent

- (instancetype)initWithBacktrace:(NSArray<NSString *> *)backtrace format:(NSString *)format arguments:(va_list)args
{
  self = [super init];
  if (self != nil) {
    static NSTimeInterval refTime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      refTime = CACurrentMediaTime();
    });
    
    // Create the format string passed to us.
    _message = [[NSString alloc] initWithFormat:format arguments:args];
	  
    NSThread *thread = [NSThread currentThread];
    NSString *threadDescription = thread.name;
    if (threadDescription.length == 0) {
      if ([thread isMainThread]) {
        threadDescription = @"Main";
      } else {
        // If the bg thread has no name, we cache a 4-character ptr string to identify it by
        // inside the thread dictionary.
        NSMutableDictionary *threadDict = thread.threadDictionary;
        threadDescription = threadDict[ASTraceEventThreadDescriptionKey];
        if (threadDescription == nil) {
          // Want these to be 4-chars to line up with "Main". It's possible that a collision could happen
          // here but it's so unbelievably likely to impact development, the risk is acceptable.
          NSString *ptrString = [NSString stringWithFormat:@"%p", thread];
          threadDescription = [ptrString substringFromIndex:MAX(0, ptrString.length - 4)];
          threadDict[ASTraceEventThreadDescriptionKey] = threadDescription;
        }
      }
    }
    _threadDescription = threadDescription;

    _backtrace = backtrace;
    _timestamp = CACurrentMediaTime() - refTime;
  }
  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<(%@) t=%7.3f: %@>", _threadDescription, _timestamp, _message];
}

@end
