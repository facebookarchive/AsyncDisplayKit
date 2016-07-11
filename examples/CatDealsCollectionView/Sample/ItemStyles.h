//
//  ItemStyles.h
//  Sample
//
//  Created by Samuel Stow on 12/30/15.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ItemStyles : NSObject
+ (NSDictionary *)titleStyle;
+ (NSDictionary *)subtitleStyle;
+ (NSDictionary *)distanceStyle;
+ (NSDictionary *)secondInfoStyle;
+ (NSDictionary *)originalPriceStyle;
+ (NSDictionary *)finalPriceStyle;
+ (NSDictionary *)soldOutStyle;
+ (NSDictionary *)badgeStyle;
+ (UIColor *)badgeColor;
+ (UIImage *)placeholderImage;
@end
