//
//  Utilities.swift
//  BackgroundPropertySetting
//
//  Created by Adlai Holler on 2/17/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit

extension UIColor {
	static func random() -> UIColor {
		return UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
	}
}
