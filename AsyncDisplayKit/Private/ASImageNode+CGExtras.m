//
//  ASImageNode+CGExtras.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASImageNode+CGExtras.h"

// TODO rewrite these to be closer to the intended use -- take UIViewContentMode as param, CGRect destinationBounds, CGSize sourceSize.
static CGSize _ASSizeFillWithAspectRatio(CGFloat aspectRatio, CGSize constraints);
static CGSize _ASSizeFitWithAspectRatio(CGFloat aspectRatio, CGSize constraints);

static CGSize _ASSizeFillWithAspectRatio(CGFloat sizeToScaleAspectRatio, CGSize destinationSize)
{
  CGFloat destinationAspectRatio = destinationSize.width / destinationSize.height;
  if (sizeToScaleAspectRatio > destinationAspectRatio) {
    return CGSizeMake(destinationSize.height * sizeToScaleAspectRatio, destinationSize.height);
  } else {
    return CGSizeMake(destinationSize.width, floorf(destinationSize.width / sizeToScaleAspectRatio));
  }
}

static CGSize _ASSizeFitWithAspectRatio(CGFloat aspectRatio, CGSize constraints)
{
  CGFloat constraintAspectRatio = constraints.width / constraints.height;
  if (aspectRatio > constraintAspectRatio) {
    return CGSizeMake(constraints.width, constraints.width / aspectRatio);
  } else {
    return CGSizeMake(constraints.height * aspectRatio, constraints.height);
  }
}

void ASCroppedImageBackingSizeAndDrawRectInBounds(CGSize sourceImageSize,
                                                  CGSize boundsSize,
                                                  UIViewContentMode contentMode,
                                                  CGRect cropRect,
                                                  BOOL forceUpscaling,
                                                  CGSize *outBackingSize,
                                                  CGRect *outDrawRect
                                                  )
{

  size_t destinationWidth = boundsSize.width;
  size_t destinationHeight = boundsSize.height;

  // Often, an image is too low resolution to completely fill the width and height provided.
  // Per the API contract as commented in the header, we will adjust input parameters (destinationWidth, destinationHeight) to ensure that the image is not upscaled on the CPU.
  CGFloat boundsAspectRatio = (float)destinationWidth / (float)destinationHeight;

  CGSize scaledSizeForImage = sourceImageSize;
  BOOL cropToRectDimensions = !CGRectIsEmpty(cropRect);

  if (cropToRectDimensions) {
    scaledSizeForImage = CGSizeMake(boundsSize.width / cropRect.size.width, boundsSize.height / cropRect.size.height);
  } else {
    if (contentMode == UIViewContentModeScaleAspectFill)
      scaledSizeForImage = _ASSizeFillWithAspectRatio(boundsAspectRatio, sourceImageSize);
    else if (contentMode == UIViewContentModeScaleAspectFit)
      scaledSizeForImage = _ASSizeFitWithAspectRatio(boundsAspectRatio, sourceImageSize);
  }

  // If fitting the desired aspect ratio to the image size actually results in a larger buffer, use the input values.
  // However, if there is a pixel savings (e.g. we would have to upscale the image), overwrite the function arguments.
  if (forceUpscaling == NO && (scaledSizeForImage.width * scaledSizeForImage.height) < (destinationWidth * destinationHeight)) {
    destinationWidth = (size_t)roundf(scaledSizeForImage.width);
    destinationHeight = (size_t)roundf(scaledSizeForImage.height);
    if (destinationWidth == 0 || destinationHeight == 0) {
      *outBackingSize = CGSizeZero;
      *outDrawRect = CGRectZero;
      return;
    }
  }

  // Figure out the scaled size within the destination bounds.
  CGFloat sourceImageAspectRatio = sourceImageSize.width / sourceImageSize.height;
  CGSize scaledSizeForDestination = CGSizeMake(destinationWidth, destinationHeight);

  if (cropToRectDimensions) {
    scaledSizeForDestination = CGSizeMake(boundsSize.width / cropRect.size.width, boundsSize.height / cropRect.size.height);
  } else {
    if (contentMode == UIViewContentModeScaleAspectFill)
      scaledSizeForDestination = _ASSizeFillWithAspectRatio(sourceImageAspectRatio, scaledSizeForDestination);
    else if (contentMode == UIViewContentModeScaleAspectFit)
      scaledSizeForDestination = _ASSizeFitWithAspectRatio(sourceImageAspectRatio, scaledSizeForDestination);
  }

  // Figure out the rectangle into which to draw the image.
  CGRect drawRect = CGRectZero;
  if (cropToRectDimensions) {
    drawRect = CGRectMake(-cropRect.origin.x * scaledSizeForDestination.width,
                          -cropRect.origin.y * scaledSizeForDestination.height,
                          scaledSizeForDestination.width,
                          scaledSizeForDestination.height);
  } else {
    // We want to obey the origin of cropRect in aspect-fill mode.
    if (contentMode == UIViewContentModeScaleAspectFill) {
      drawRect = CGRectMake(((destinationWidth - scaledSizeForDestination.width) * cropRect.origin.x),
                            ((destinationHeight - scaledSizeForDestination.height) * cropRect.origin.y),
                            scaledSizeForDestination.width,
                            scaledSizeForDestination.height);

    }
    // And otherwise just center it.
    else {
      drawRect = CGRectMake(((destinationWidth - scaledSizeForDestination.width) / 2.0),
                            ((destinationHeight - scaledSizeForDestination.height) / 2.0),
                            scaledSizeForDestination.width,
                            scaledSizeForDestination.height);
    }
  }

  *outDrawRect = drawRect;
  *outBackingSize = CGSizeMake(destinationWidth, destinationHeight);
}
