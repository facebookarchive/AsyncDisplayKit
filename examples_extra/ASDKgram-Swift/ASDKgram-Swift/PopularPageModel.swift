//
//  PopularPageModel.swift
//  ASDKgram-Swift
//
//  Created by Calum Harris on 08/01/2017.
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

import Foundation

class PopularPageModel: NSObject {

	let page: Int
	let totalPages: Int
	let totalNumberOfItems: Int
	let photos: [PhotoModel]

	init?(dictionary: JSONDictionary, photosArray: [PhotoModel]) {
		guard let page = dictionary["current_page"] as? Int, let totalPages = dictionary["total_pages"] as? Int, let totalItems = dictionary["total_items"] as? Int else { print("error parsing JSON within PhotoModel Init"); return nil }

		self.page = page
		self.totalPages = totalPages
		self.totalNumberOfItems = totalItems
		self.photos = photosArray
	}
}
