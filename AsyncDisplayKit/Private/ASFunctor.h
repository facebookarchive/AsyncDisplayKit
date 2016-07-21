//
//  ASFunctor.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

/* generic functors */

namespace ASDK {
  
  template<class T>
  struct DescribeFunctor {
    NSString *operator()(const T &t) const {
      return [NSString stringWithFormat:@"%d", static_cast<int>(t)];
    }
  };
  
  template<class T>
  struct HashFunctor {
    size_t operator()(const T &key) const {
      return (size_t)(key);
    }
  };
  
  template<class T>
  struct EqualFunctor {
    bool operator()(const T &left, const T&right) const {
      return left == right;
    }
  };
  
  template<class T>
  struct CompareFunctor {
    bool operator()(const T &left, const T &right) const {
      return (int)left < (int)right;
    };
  };
  
  template<class T>
  struct RoundToIntegerFunctor {
    T operator()(const T &t) const {
      return t;
    }
  };

  template<class T>
  struct RoundToSubFunctor {
    T operator()(const T &t, float sub) const {
      return t;
    }
  };

}
