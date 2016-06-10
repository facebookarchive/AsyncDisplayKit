//
//  AppDelegate.swift
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    let window = UIWindow(frame: UIScreen.mainScreen().bounds)
    window.backgroundColor = UIColor.whiteColor()
    window.rootViewController = ViewController(nibName: nil, bundle: nil)
    window.makeKeyAndVisible()
    self.window = window
    return true
  }

}
