/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#include <CoreGraphics/CGBase.h>
#import "ASBaseDefines.h"

ASDISPLAYNODE_EXTERN_C_BEGIN

BOOL ASSubclassOverridesSelector(Class superclass, Class subclass, SEL selector);

CGFloat ASScreenScale();

CGFloat ASFloorPixelValue(CGFloat f);

CGFloat ASCeilPixelValue(CGFloat f);

CGFloat ASRoundPixelValue(CGFloat f);

ASDISPLAYNODE_EXTERN_C_END
