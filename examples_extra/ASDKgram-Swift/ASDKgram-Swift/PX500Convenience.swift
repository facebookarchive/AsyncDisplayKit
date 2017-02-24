//
//  PX500Convenience.swift
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

func parsePopularPage(withURL: URL) -> Resource<PopularPageModel> {

	let parse = Resource<PopularPageModel>(url: withURL, parseJSON: { jsonData in

		guard let json = jsonData as? JSONDictionary, let photos = json["photos"] as? [JSONDictionary] else { return .failure(.errorParsingJSON)  }

		guard let model = PopularPageModel(dictionary: json, photosArray: photos.flatMap(PhotoModel.init)) else { return .failure(.errorParsingJSON) }

		return .success(model)
	})

	return parse
}
