//
//  NetworkImageView.swift
//  ASDKgram-Swift
//
//  Created by Calum Harris on 09/01/2017.
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
//   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit

let imageCache = NSCache<NSString, UIImage>()

class NetworkImageView: UIImageView {

	var imageUrlString: String?

	func loadImageUsingUrlString(urlString: String) {

		imageUrlString = urlString

		let url = URL(string: urlString)

		image = nil

		if let imageFromCache = imageCache.object(forKey: urlString as NSString) {
			self.image = imageFromCache
			return
		}

		URLSession.shared.dataTask(with: url!, completionHandler: { (data, respones, error) in

			if error != nil {
				print(error!)
				return
			}

			DispatchQueue.main.async {
				let imageToCache = UIImage(data: data!)
				if self.imageUrlString == urlString {
					self.image = imageToCache
				}
				imageCache.setObject(imageToCache!, forKey: urlString as NSString)
			}
		}).resume()
	}
}
