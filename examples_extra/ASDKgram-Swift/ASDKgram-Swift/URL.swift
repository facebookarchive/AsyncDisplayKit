//
//  URL.swift
//  ASDKgram-Swift
//
//  Created by Calum Harris on 07/01/2017.
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

extension URL {

	static func URLForFeedModelType(feedModelType: PhotoFeedModelType) -> URL {
		switch feedModelType {
		case .photoFeedModelTypePopular:
			return URL(string: assemble500PXURLString(endpoint: Constants.PX500.URLS.PopularEndpoint))!

		case .photoFeedModelTypeLocation:
			return URL(string: assemble500PXURLString(endpoint: Constants.PX500.URLS.SearchEndpoint))!

		case .photoFeedModelTypeUserPhotos:
			return URL(string: assemble500PXURLString(endpoint: Constants.PX500.URLS.UserEndpoint))!
		}
	}

	private static func assemble500PXURLString(endpoint: String) -> String {
		return Constants.PX500.URLS.Host + endpoint + Constants.PX500.URLS.ConsumerKey
	}

	mutating func addImageParameterForClosestImageSizeAndpage(size: CGSize, page: Int) -> URL {

		let imageParameterID: Int

		if size.height <= 70 {
			imageParameterID = 1
		} else if size.height <= 100 {
				imageParameterID = 100
		} else if size.height <= 140 {
				imageParameterID = 2
		} else if size.height <= 200 {
				imageParameterID = 200
		} else if size.height <= 280 {
				imageParameterID = 3
		} else if size.height <= 400 {
				imageParameterID = 400
		} else {
				imageParameterID = 600
		}

		var urlString = self.absoluteString
		urlString.append("&image_size=\(imageParameterID)&page=\(page)")

		return URL(string: urlString)!
	}

}
