/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASCoreAnimationExtras.h"

#import "ASAssert.h"

extern void ASDisplayNodeSetupLayerContentsWithResizableImage(CALayer *layer, UIImage *image)
{
  // FIXME: This method does not currently handle UIImageResizingModeTile, which is the default on iOS 6.
  // I'm not sure of a way to use CALayer directly to perform such tiling on the GPU, though the stretch is handled by the GPU,
  // and CALayer.h documents the fact that contentsCenter is used to stretch the pixels.

  if (image) {

    // Image may not actually be stretchable in one or both dimensions; this is handled
    layer.contents = (id)[image CGImage];
    layer.contentsScale = [image scale];
    layer.rasterizationScale = [image scale];
    CGSize imageSize = [image size];

    ASDisplayNodeCAssert(image.resizingMode == UIImageResizingModeStretch || UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero),
             @"the resizing mode of image should be stretch; if not, then its insets must be all-zero");

    UIEdgeInsets insets = [image capInsets];

    // These are lifted from what UIImageView does by experimentation. Without these exact values, the stretching is slightly off.
    const float halfPixelFudge = 0.49f;
    const float otherPixelFudge = 0.02f;
    // Convert to unit coordinates for the contentsCenter property.
    CGRect contentsCenter = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    if (insets.left > 0 || insets.right > 0) {
      contentsCenter.origin.x = ((insets.left + halfPixelFudge) / imageSize.width);
      contentsCenter.size.width = (imageSize.width - (insets.left + insets.right + 1.f) + otherPixelFudge) / imageSize.width;
    }
    if (insets.top > 0 || insets.bottom > 0) {
      contentsCenter.origin.y = ((insets.top + halfPixelFudge) / imageSize.height);
      contentsCenter.size.height = (imageSize.height - (insets.top + insets.bottom + 1.f) + otherPixelFudge) / imageSize.height;
    }
    layer.contentsGravity = kCAGravityResize;
    layer.contentsCenter = contentsCenter;

  } else {
    layer.contents = nil;
  }
}


struct _UIContentModeStringLUTEntry {
  UIViewContentMode contentMode;
  NSString *const string;
};

static const struct _UIContentModeStringLUTEntry UIContentModeCAGravityLUT[] = {
  {UIViewContentModeScaleToFill,     kCAGravityResize},
  {UIViewContentModeScaleAspectFit,  kCAGravityResizeAspect},
  {UIViewContentModeScaleAspectFill, kCAGravityResizeAspectFill},
  {UIViewContentModeCenter,          kCAGravityCenter},
  {UIViewContentModeTop,             kCAGravityBottom},
  {UIViewContentModeBottom,          kCAGravityTop},
  {UIViewContentModeLeft,            kCAGravityLeft},
  {UIViewContentModeRight,           kCAGravityRight},
  {UIViewContentModeTopLeft,         kCAGravityBottomLeft},
  {UIViewContentModeTopRight,        kCAGravityBottomRight},
  {UIViewContentModeBottomLeft,      kCAGravityTopLeft},
  {UIViewContentModeBottomRight,     kCAGravityTopRight},
};

static const struct _UIContentModeStringLUTEntry UIContentModeDescriptionLUT[] = {
  {UIViewContentModeScaleToFill,     @"scaleToFill"},
  {UIViewContentModeScaleAspectFit,  @"aspectFit"},
  {UIViewContentModeScaleAspectFill, @"aspectFill"},
  {UIViewContentModeRedraw,          @"redraw"},
  {UIViewContentModeCenter,          @"center"},
  {UIViewContentModeTop,             @"top"},
  {UIViewContentModeBottom,          @"bottom"},
  {UIViewContentModeLeft,            @"left"},
  {UIViewContentModeRight,           @"right"},
  {UIViewContentModeTopLeft,         @"topLeft"},
  {UIViewContentModeTopRight,        @"topRight"},
  {UIViewContentModeBottomLeft,      @"bottomLeft"},
  {UIViewContentModeBottomRight,     @"bottomRight"},
};

NSString *ASDisplayNodeNSStringFromUIContentMode(UIViewContentMode contentMode) {
  for (int i=0; i< ARRAY_COUNT(UIContentModeDescriptionLUT); i++) {
    if (UIContentModeDescriptionLUT[i].contentMode == contentMode) {
      return UIContentModeDescriptionLUT[i].string;
    }
  }
  return [NSString stringWithFormat:@"%d", (int)contentMode];
}

UIViewContentMode ASDisplayNodeUIContentModeFromNSString(NSString *string) {
  // If you passed one of the constants (this is just an optimization to avoid string comparison)
  for (int i=0; i < ARRAY_COUNT(UIContentModeDescriptionLUT); i++) {
    if (UIContentModeDescriptionLUT[i].string == string) {
      return UIContentModeDescriptionLUT[i].contentMode;
    }
  }
  // If you passed something isEqualToString: to one of the constants
  for (int i=0; i < ARRAY_COUNT(UIContentModeDescriptionLUT); i++) {
    if ([UIContentModeDescriptionLUT[i].string isEqualToString:string]) {
      return UIContentModeDescriptionLUT[i].contentMode;
    }
  }
  return UIViewContentModeScaleToFill;
}

NSString *const ASDisplayNodeCAContentsGravityFromUIContentMode(UIViewContentMode contentMode)
{
  for (int i=0; i < ARRAY_COUNT(UIContentModeCAGravityLUT); i++) {
    if (UIContentModeCAGravityLUT[i].contentMode == contentMode) {
      return UIContentModeCAGravityLUT[i].string;
    }
  }
  ASDisplayNodeCAssert(contentMode == UIViewContentModeRedraw, @"Encountered an unknown contentMode %zd. Is this a new version of iOS?", contentMode);
  // Redraw is ok to return nil.
  return nil;
}

UIViewContentMode ASDisplayNodeUIContentModeFromCAContentsGravity(NSString *const contentsGravity)
{
  // If you passed one of the constants (this is just an optimization to avoid string comparison)
  for (int i=0; i < ARRAY_COUNT(UIContentModeCAGravityLUT); i++) {
    if (UIContentModeCAGravityLUT[i].string == contentsGravity) {
      return UIContentModeCAGravityLUT[i].contentMode;
    }
  }
  // If you passed something isEqualToString: to one of the constants
  for (int i=0; i < ARRAY_COUNT(UIContentModeCAGravityLUT); i++) {
    if ([UIContentModeCAGravityLUT[i].string isEqualToString:contentsGravity]) {
      return UIContentModeCAGravityLUT[i].contentMode;
    }
  }
  ASDisplayNodeCAssert(contentsGravity, @"Encountered an unknown contentsGravity \"%@\". Is this a new version of iOS?", contentsGravity);
  ASDisplayNodeCAssert(!contentsGravity, @"You passed nil to ASDisplayNodeUIContentModeFromCAContentsGravity. We're falling back to resize, but this is probably a bug.");
  // If asserts disabled, fall back to this
  return UIViewContentModeScaleToFill;
}
