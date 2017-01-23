//
//  ASLayoutSpecUtilities.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <algorithm>
#import <functional>
#import <type_traits>
#import <vector>

#import <UIKit/UIKit.h>

namespace AS {
  // adopted from http://stackoverflow.com/questions/14945223/map-function-with-c11-constructs
  // Takes an iterable, applies a function to every element,
  // and returns a vector of the results
  //
  template <typename T, typename Func>
  auto map(const T &iterable, Func &&func) -> std::vector<decltype(func(std::declval<typename T::value_type>()))>
  {
    // Some convenience type definitions
    typedef decltype(func(std::declval<typename T::value_type>())) value_type;
    typedef std::vector<value_type> result_type;

    // Prepares an output vector of the appropriate size
    result_type res(iterable.size());

    // Let std::transform apply `func` to all elements
    // (use perfect forwarding for the function object)
    std::transform(
                   begin(iterable), end(iterable), res.begin(),
                   std::forward<Func>(func)
                   );

    return res;
  }

  template<typename Func>
  auto map(id<NSFastEnumeration> collection, Func &&func) -> std::vector<decltype(func(std::declval<id>()))>
  {
    std::vector<decltype(func(std::declval<id>()))> to;
    for (id obj in collection) {
      to.push_back(func(obj));
    }
    return to;
  }

  template <typename T, typename Func>
  auto filter(const T &iterable, Func &&func) -> std::vector<typename T::value_type>
  {
    std::vector<typename T::value_type> to;
    for (auto obj : iterable) {
      if (func(obj)) {
        to.push_back(obj);
      }
    }
    return to;
  }
};

inline CGPoint operator+(const CGPoint &p1, const CGPoint &p2)
{
  return { p1.x + p2.x, p1.y + p2.y };
}

inline CGPoint operator-(const CGPoint &p1, const CGPoint &p2)
{
  return { p1.x - p2.x, p1.y - p2.y };
}

inline CGSize operator+(const CGSize &s1, const CGSize &s2)
{
  return { s1.width + s2.width, s1.height + s2.height };
}

inline CGSize operator-(const CGSize &s1, const CGSize &s2)
{
  return { s1.width - s2.width, s1.height - s2.height };
}

inline UIEdgeInsets operator+(const UIEdgeInsets &e1, const UIEdgeInsets &e2)
{
  return { e1.top + e2.top, e1.left + e2.left, e1.bottom + e2.bottom, e1.right + e2.right };
}

inline UIEdgeInsets operator-(const UIEdgeInsets &e1, const UIEdgeInsets &e2)
{
  return { e1.top - e2.top, e1.left - e2.left, e1.bottom - e2.bottom, e1.right - e2.right };
}

inline UIEdgeInsets operator*(const UIEdgeInsets &e1, const UIEdgeInsets &e2)
{
  return { e1.top * e2.top, e1.left * e2.left, e1.bottom * e2.bottom, e1.right * e2.right };
}

inline UIEdgeInsets operator-(const UIEdgeInsets &e)
{
  return { -e.top, -e.left, -e.bottom, -e.right };
}

