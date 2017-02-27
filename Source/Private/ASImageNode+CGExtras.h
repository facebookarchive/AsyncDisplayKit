//
//  ASImageNode+CGExtras.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

ASDISPLAYNODE_EXTERN_C_BEGIN


/**
 @abstract Decides how to scale and crop an image to fit in the provided size, while not wasting memory by upscaling images
 @param sourceImageSize The size of the encoded image.
 @param boundsSize The bounds in which the image will be displayed.
 @param contentMode The mode that defines how image will be scaled and cropped to fit. Supported values are UIViewContentModeScaleToAspectFill and UIViewContentModeScaleToAspectFit.
 @param cropRect A rectangle that is to be featured by the cropped image. The rectangle is specified as a "unit rectangle," using fractions of the source image's width and height, e.g. CGRectMake(0.5, 0, 0.5, 1.0) will feature the full right half a photo. If the cropRect is empty, the contentMode will be used to determine the drawRect's size, and only the cropRect's origin will be used for positioning.
 @param forceUpscaling A boolean that indicates you would *not* like the backing size to be downscaled if the image is smaller than the destination size. Setting this to YES will result in higher memory usage when images are smaller than their destination.
 @param forcedSize A CGSize, that if non-CGSizeZero, indicates that the backing size should be forcedSize and not calculated based on boundsSize.
 @discussion If the image is smaller than the size and UIViewContentModeScaleToAspectFill is specified, we suggest the input size so it will be efficiently upscaled on the GPU by the displaying layer at composite time.
 */
extern void ASCroppedImageBackingSizeAndDrawRectInBounds(CGSize sourceImageSize,
                                                         CGSize boundsSize,
                                                         UIViewContentMode contentMode,
                                                         CGRect cropRect,
                                                         BOOL forceUpscaling,
                                                         CGSize forcedSize,
                                                         CGSize *outBackingSize,
                                                         CGRect *outDrawRect
                                                         );

ASDISPLAYNODE_EXTERN_C_END
