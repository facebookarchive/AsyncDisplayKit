//
//  Constants
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
// swiftlint:disable nesting

import UIKit

struct Constants {

	struct PX500 {
		struct URLS {
			static let Host = "https://api.500px.com/v1/"
			static let PopularEndpoint = "photos?feature=popular&exclude=Nude,People,Fashion&sort=rating&image_size=3&include_store=store_download&include_states=voted"
			static let SearchEndpoint = "photos/search?geo="    //latitude,longitude,radius<units>
			static let UserEndpoint = "photos?user_id="
			static let ConsumerKey = "&consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC"
		}
	}

	struct CellLayout {
		static let FontSize: CGFloat = 14
		static let HeaderHeight: CGFloat = 50
		static let UserImageHeight: CGFloat = 30
		static let HorizontalBuffer: CGFloat = 10
		static let VerticalBuffer: CGFloat = 5
		static let InsetForAvatar = UIEdgeInsets(top: HorizontalBuffer, left: 0, bottom: HorizontalBuffer, right: HorizontalBuffer)
		static let InsetForHeader = UIEdgeInsets(top: 0, left: HorizontalBuffer, bottom: 0, right: HorizontalBuffer)
		static let InsetForFooter = UIEdgeInsets(top: VerticalBuffer, left: HorizontalBuffer, bottom: VerticalBuffer, right: HorizontalBuffer)
	}
}
