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

extension NSAttributedString {

  static func attributedString(string: String, fontSize size: CGFloat, color: UIColor?, firstWordColor: UIColor?) -> NSAttributedString {
    let attributes = [NSForegroundColorAttributeName: color ?? UIColor.black,
                      NSFontAttributeName: UIFont.boldSystemFont(ofSize: size)]

    let attributedString = NSMutableAttributedString(string: string, attributes: attributes)

    if let firstWordColor = firstWordColor {
      let nsString = string as NSString
      let firstSpaceRange = nsString.rangeOfCharacter(from: NSCharacterSet.whitespaces)
      let firstWordRange  = NSMakeRange(0, firstSpaceRange.location)
      attributedString.addAttribute(NSForegroundColorAttributeName, value: firstWordColor, range: firstWordRange)
    }

    return attributedString
  }

}
