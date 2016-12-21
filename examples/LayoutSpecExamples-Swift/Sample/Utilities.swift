//
//  Utilities.swift
//  Sample
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

import UIKit
import Foundation

extension UIColor {

  static func darkBlueColor() -> UIColor {
    return UIColor(red: 18.0/255.0, green: 86.0/255.0, blue: 136.0/255.0, alpha: 1.0)
  }

  static func lightBlueColor() -> UIColor {
    return UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)
  }

  static func duskColor() -> UIColor {
    return UIColor(red: 255/255.0, green: 181/255.0, blue: 68/255.0, alpha: 1.0)
  }

  static func customOrangeColor() -> UIColor {
    return UIColor(red: 40/255.0, green: 43/255.0, blue: 53/255.0, alpha: 1.0)
  }

}

extension UIImage {

  func makeCircularImage(size: CGSize, borderWidth width: CGFloat) -> UIImage {
    // make a CGRect with the image's size
    let circleRect = CGRect(origin: .zero, size: size)

    // begin the image context since we're not in a drawRect:
    UIGraphicsBeginImageContextWithOptions(circleRect.size, false, 0)

    // create a UIBezierPath circle
    let circle = UIBezierPath(roundedRect: circleRect, cornerRadius: circleRect.size.width * 0.5)

    // clip to the circle
    circle.addClip()

    UIColor.white.set()
    circle.fill()

    // draw the image in the circleRect *AFTER* the context is clipped
    self.draw(in: circleRect)

    // create a border (for white background pictures)
    if width > 0 {
      circle.lineWidth = width;
      UIColor.white.set()
      circle.stroke()
    }

    // get an image from the image context
    let roundedImage = UIGraphicsGetImageFromCurrentImageContext();

    // end the image context since we're not in a drawRect:
    UIGraphicsEndImageContext();

    return roundedImage ?? self
  }

}

extension NSAttributedString {

  static func attributedString(string: String?, fontSize size: CGFloat, color: UIColor?) -> NSAttributedString? {
    guard let string = string else { return nil }

    let attributes = [NSForegroundColorAttributeName: color ?? UIColor.black,
                      NSFontAttributeName: UIFont.boldSystemFont(ofSize: size)]

    let attributedString = NSMutableAttributedString(string: string, attributes: attributes)

    return attributedString
  }
  
}
