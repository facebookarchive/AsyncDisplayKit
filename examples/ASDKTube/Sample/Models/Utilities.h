//
//  Utilities.h
//  Sample
//
//  Created by Hannah Troisi on 3/9/16.
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
#include <UIKit/UIKit.h>
@interface UIColor (Additions)

+ (UIColor *)lighOrangeColor;
+ (UIColor *)darkBlueColor;
+ (UIColor *)lightBlueColor;

@end

@interface UIImage (Additions)

+ (UIImage *)followingButtonStretchableImageForCornerRadius:(CGFloat)cornerRadius following:(BOOL)followingEnabled;
+ (void)downloadImageForURL:(NSURL *)url completion:(void (^)(UIImage *))block;

- (UIImage *)makeCircularImageWithSize:(CGSize)size;

@end

@interface NSString (Additions)

// returns a user friendly elapsed time such as '50s', '6m' or '3w'
+ (NSString *)elapsedTimeStringSinceDate:(NSString *)uploadDateString;

@end

@interface NSAttributedString (Additions)

+ (NSAttributedString *)attributedStringWithString:(NSString *)string
                                          fontSize:(CGFloat)size
                                             color:(UIColor *)color
                                    firstWordColor:(UIColor *)firstWordColor;

@end