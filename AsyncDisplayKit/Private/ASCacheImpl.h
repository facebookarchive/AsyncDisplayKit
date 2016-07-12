//
//  ASCacheImpl.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import "ASFunctor.h"
#import "ASAssert.h"

#import <CoreGraphics/CoreGraphics.h>
#include <mutex>
#include <unordered_map>
#include <list>
#include <map>
#include <vector>
#include <utility>
#include <string>
#include <type_traits>

namespace ASDK {

  /**
   Templated cache class, based on:
   http://aim.adc.rmit.edu.au/phd/sgreuter/papers/graphite2003.pdf
   https://web.archive.org/web/20061210151616/http://aim.adc.rmit.edu.au/phd/sgreuter/papers/graphite2003.pdf

   Cache Interface

   In ObjectiveC pattern is to provide configuration with init method. We'll use pointer to interface and create concrete
   classes based on runtime parameters for caching strategies.

   Example:
      typedef NSObject *__strong KeyT; // MUST be NSObject*, not id if you plan to use ASDK::HashFunctor and ASDK::EqualFunctor
      typedef NSObject *__strong ValueT; //HashFunctor and EqualFunctor will use pointer equality for id, not -hash/-isEqual:.

      ASDK::Cache<KeyT, ValueT> *_imp;  // pointer to implementation

   concrete implementations for various strategies:

      typedef ASDK::CacheImpl<KeyT, ValueT> ASCacheLRUImpl;
      typedef ASDK::CacheImpl<KeyT, ValueT, ASDK::HashFunctor<KeyT>, ASDK::EqualFunctor<KeyT>, ASDK::CacheL2LRUStrategy> ASCacheL2LRUImpl;

   Now, in init:
    _imp = new ASCacheLRUImpl(...);


   C++ example:
      typedef std::pair<int, char> Apartment; // Lets' create a cache where key is a pair

      // If someone has specified a generic hasher for Apartment by specializing ASDK::HashFunctor, ASDK::Cache will use that hasher by
      // default. Otherwise, you can create a hasher and pass it to the cache directly as a template argument and it
      // will apply just to this cache.
      struct HashApartemnt {
        size_t operator()(const Apartment &obj) const {
            return (size_t)obj.first * 31 + obj.second;
        }
      };

      // If your key type does have ==, you can use default EqualFunctor, if not you have to provide one.
      // Default ASDK::EqualFunctor will just call operator== for the type, so one for the pair is defined in stl already.

      // Cache with default strategy and default EqualFunctor
      typedef ASDK::CacheImpl<Apartment, std::string, HashApartemnt> ApartmentsLRUCache;

      // Cache with L2LRU Strategy (and default EqualFunctor)
      typedef ASDK::CacheImpl<Apartment, std::string, HashApartemnt, ASDK::EqualFunctor<Apartment>, ASDK::CacheL2LRUStrategy> ApartmentsL2LRUCache;

      ApartmentsL2LRUCache acache(0, 0.2, preferredItemCostLimit, preferredItemsTotalCostLimit);

      acache.insert(std::make_pair<int, char>(2, 'J'), "Fancy Plaza", 1);
      acache.insert(std::make_pair<int, char>(2, 'F'), "Sans Souci", 1);
      acache.insert(std::make_pair<int, char>(2, 'J'), "Winsdor", 1); //replaces the first one

      for (auto& key_val : acache) {
        Apartment const& apt = key_val.first;
        std::string const& building = key_val.second;
        ...
      }

      Implementation:
         Wrapper around unordered map with support for eviction strategies and limited cost. Interface is non-virtual
         and concrete strategies will implement customized behaviour.
   */
  template <typename KeyT, typename ValueT, typename Hasher=HashFunctor<KeyT>, typename KeyEqual=EqualFunctor<KeyT>>
  class Cache
  {
  private:
    // Underlying data structure
    typedef std::unordered_map<KeyT, ValueT, Hasher, KeyEqual> CacheMapT;
    CacheMapT _keysToItems;

  public:

    // Make Cache similar to std container, so that it can easily be iterated, used in for range loops, algos, etc.
    typedef typename CacheMapT::key_type key_type;
    typedef ValueT data_type;
    typedef ValueT mapped_type;
    typedef typename CacheMapT::value_type value_type;
    typedef typename CacheMapT::hasher hasher;
    typedef typename CacheMapT::key_equal key_equal;

    typedef typename CacheMapT::size_type size_type;
    typedef typename CacheMapT::difference_type difference_type;
    typedef typename CacheMapT::pointer pointer;
    typedef typename CacheMapT::const_pointer const_pointer;
    typedef typename CacheMapT::reference reference;
    typedef typename CacheMapT::const_reference const_reference;

    typedef typename CacheMapT::iterator iterator;
    typedef typename CacheMapT::const_iterator const_iterator;

    typedef typename CacheMapT::allocator_type allocator_type;

    hasher hash_funct() const { return _keysToItems.hash_funct(); }
    key_equal key_eq() const { return _keysToItems.key_eq(); }
    allocator_type get_allocator() const { return _keysToItems.get_allocator(); }

    iterator begin() { return _keysToItems.begin(); }
    iterator end() { return _keysToItems.end(); }
    const_iterator begin() const { return _keysToItems.begin(); }
    const_iterator end() const { return _keysToItems.end(); }

    // Creators/Destructors
    Cache(const std::string &cacheName, NSUInteger maxCost, CGFloat compactionFactor)
    : _cacheName(cacheName),
      _maxCost(maxCost),
      _compactionFactor(compactionFactor)
    {
    }
    virtual ~Cache() = default;

    // Accessors
    NSUInteger getMaxCost() const { return _maxCost; }
    std::size_t count() const { return _keysToItems.size(); }
    NSUInteger totalCost() const { return getCurrentCost(); }
    CGFloat compactionFactor() const { return _compactionFactor; }

    void setCompactionFactor(CGFloat newFactor) { _compactionFactor = newFactor; }

    void removeAllObjects()
    {
      _keysToItems.clear();
      onClear();
    }

    void removeObjectForKey(const KeyT &first)
    {
      auto i = _keysToItems.find(first);
      if (i == _keysToItems.end()) {
        return;
      }
      // Don't swap the two statements; erasure from _keysToItems invalidates i!
      onRemoveItem(i->first);
      _keysToItems.erase(i->first);
    }

    void compact()
    {
      compact(_compactionFactor);
    }

    /** Executes a forced compact based on any given compaction factor. */
    void compact(CGFloat compactionFactor)
    {
      const CGFloat clampedFactor = std::max(std::min(compactionFactor, (CGFloat)1), (CGFloat)0);
      _eraseItemsWithCost(ceil((CGFloat)getCurrentCost() * clampedFactor));
    }

    void insert(const KeyT &key, const ValueT &value, const NSUInteger cost)
    {
      onInsertItem(key, cost);
      _keysToItems[key] = value;
      _compactIfNeeded();
    }

    ValueT find(const KeyT &first, ValueT notFoundValue, bool touch = true)  // not const, since it modifies _costs
    {
      auto i = _keysToItems.find(first);
      if (i == _keysToItems.end()) {
        _miss++;
        return notFoundValue;
      } else {
        _hit++;
        if (touch) {
          // LRU
          onItemHit(i->first);
        }

        return i->second;
      }
    }

    template<
      typename... Dummy,
      typename U = ValueT,
      typename = typename std::enable_if<std::is_pointer<U>::value, void>::type
    >
    ValueT find(const KeyT &first, bool touch = true)  // not const, since it modifies _costs
    {
      static_assert(sizeof...(Dummy)==0, "Do not specify template arguments!");
      return find(first, nil, touch);
    }

  private:
    // identifier of cache
    const std::string _cacheName;

    // total costs this cache can hold
    NSUInteger _maxCost;

    NSUInteger _hit = 0;
    NSUInteger _miss = 0;

    CGFloat _compactionFactor;

    // Customization for strategies (template method pattern). Implemented in derived classes with concrete strategies
    virtual void onClear() = 0;
    virtual void onRemoveItem(KeyT const& key) = 0;
    virtual void onInsertItem(KeyT const& key, NSUInteger cost) = 0;
    virtual void onItemHit(KeyT const& key) = 0;
    virtual std::vector<KeyT> onCompact(NSUInteger toEraseCost) = 0;
    virtual NSUInteger getCurrentCost() const = 0;

    /**
     passive compact, only get called during internal insert() method
     */
    void _compactIfNeeded()
    {
      if (_maxCost == 0) {
        return;
      }

      const NSUInteger currentCost = getCurrentCost();
      if (currentCost <= _maxCost) {
        return;
      }

      const NSUInteger targetCost = floorf((float)_maxCost * (1 - _compactionFactor));
      _eraseItemsWithCost(currentCost - targetCost);
    }

    void _eraseItemsWithCost(NSUInteger toEraseCost)
    {
      if (toEraseCost == 0) {
        return;
      }

      std::vector<KeyT> keysToRemove(std::move(onCompact(toEraseCost)));
      for (const auto &key : keysToRemove) {
        _keysToItems.erase(key);
      }
    }
  };

  /**
    Strategies.

    To be used with CacheImpl, they need to fulfill following interface
       void insertItem(const Key &key, const NSUInteger cost);
       void moveItemAfterHit(const Key &key);
       void removeItem(const Key &key);
       vector<KeyT> compactWithCost(const NSUInteger cost); //Returns keys removed during compaction
       void clear();
   */

  /**
   CacheLRUStrategy

   This is a regular LRU strategy. If a cache hit happens, item will be placed at the front of the queue.
   Each insertion will also be placed at the front.
   */
  template <typename KeyT, typename ValueT, typename Hasher, typename KeyEqual>
  class CacheLRUStrategy
  {
  private:
    //! Types
    typedef std::list<std::pair<KeyT,NSUInteger>> LRUQueue;
    typedef std::unordered_map<KeyT, typename LRUQueue::iterator, Hasher, KeyEqual> Indexer;

    NSUInteger _currentCost = 0;
    LRUQueue _costs;
    Indexer _keysToCosts;

  public:

    NSUInteger getCurrentCost() const { return _currentCost; }

    void clear()
    {
      _currentCost = 0;
      _costs.clear();
      _keysToCosts.clear();
    }

    void insertItem(const KeyT &key, const NSUInteger cost)
    {
      auto it = _keysToCosts.find(key);
      if (it != _keysToCosts.end()) {
        _currentCost -= it->second->second;
        _costs.erase(it->second);
      }
      _currentCost += cost;
      _keysToCosts[key] = _costs.insert(_costs.begin(), std::make_pair(key, cost));
    }

    void moveItemAfterHit(const KeyT &key)
    {
      auto it = _keysToCosts.find(key);
      ASDisplayNodeCAssertTrue(it != _keysToCosts.end());
      _costs.splice(_costs.begin(), _costs, it->second);
    }

    void removeItem(const KeyT &key)
    {
      auto it = _keysToCosts.find(key);
      if (it != _keysToCosts.end()) {
        _currentCost -= it->second->second;
        _costs.erase(it->second);
        _keysToCosts.erase(it);
      }
    }

    std::vector<KeyT> compactWithCost(const NSUInteger costToErase)
    {
      std::vector<KeyT> keysRemoved;
      NSInteger toErase = costToErase;

      auto rit = _costs.rbegin();

      while (toErase > 0 && rit != _costs.rend()) {
        toErase -= rit->second;
        _currentCost -= rit->second;
        keysRemoved.push_back(rit->first);
        _keysToCosts.erase(rit->first);
        rit = typename LRUQueue::reverse_iterator(_costs.erase((++rit).base()));
      }
      return keysRemoved;
    }
  };

  /**
   CacheL2LRUStrategy

   Caching strategy for items, preferring items with smaller cost.
   Cache will be divided into two fixed size areas L1 (preferred Items) & L2 (regular/expensive Items)
   evcition always happens in the L2 area first.
   */
  template <typename KeyT, typename ValueT, typename HashFunc=HashFunctor<KeyT>, typename EqFunc=EqualFunctor<KeyT>>
  class CacheL2LRUStrategy
  {
    //! Types
    typedef std::list<std::pair<KeyT,NSUInteger> > LRUQueue;
    typedef std::unordered_map<KeyT,typename LRUQueue::iterator, HashFunc,EqFunc> Indexer;

    private:

    // the head of the second list, it is somewhere in the middle of the original list
    LRUQueue _costs;
    Indexer _keysToCosts;
    NSUInteger _currentCost = 0;

    /**
     Index for keeping track of what are in L1 preferred item cache, use it for O(1) access.
     */
    Indexer _keysToPreferredItemCosts;

    /**
     The iterator points to the beginning of the list of regular (expensive) items.
     */
    typename LRUQueue::iterator _regularItemsQueueBegin = _costs.end();

    // total size of L1 cache, if set to 0, there is no L1 cache.
    const NSUInteger _preferredItemsTotalCostLimit;

    // current total cost of L1 cache
    NSUInteger _preferredItemsCurrentCost = 0;

    // if item cost < _preferredItemCostLimit, it can be put into L1 cache
    const NSUInteger _preferredItemCostLimit;

    // if L1 cache is full, each time it will try to move _preferredItemsCompactFactor * _preferredItemsTotalCostLimit cost items to L2
    const CGFloat _preferredItemsCompactFactor = 0.2;

  private:
    void _compactPreferredItemsQueueIfNeeded()
    {
      if (_preferredItemsCurrentCost > _preferredItemsTotalCostLimit) {
        while (_preferredItemsCurrentCost > _preferredItemsTotalCostLimit * (1 - _preferredItemsCompactFactor)) {
          --_regularItemsQueueBegin;
          _keysToPreferredItemCosts.erase(_regularItemsQueueBegin->first);
          _preferredItemsCurrentCost -= _regularItemsQueueBegin->second;
        }
      }
    }

    /**
     internal shared function, call by several public functions for removing items
     */
    typename LRUQueue::iterator _removeItem(const KeyT &key)
    {
      auto it = _keysToCosts.find(key);
      if (it == _keysToCosts.end()) {
        return _costs.end();
      }

      if (it->second == _regularItemsQueueBegin) {
        ++_regularItemsQueueBegin;
      }

      auto itPreferred = _keysToPreferredItemCosts.find(key);
      if (itPreferred != _keysToPreferredItemCosts.end()) {
        _preferredItemsCurrentCost -= itPreferred->second->second;
        _keysToPreferredItemCosts.erase(itPreferred);
      }

      _currentCost -= it->second->second;
      auto ret = _costs.erase(it->second);
      _keysToCosts.erase(it);
      return ret;
    }

  public:

    NSUInteger getCurrentCost() const { return _currentCost; }

    void clear()
    {
      _costs.clear();
      _keysToCosts.clear();
      _preferredItemsCurrentCost = 0;
      _regularItemsQueueBegin = _costs.end();
      _keysToPreferredItemCosts.clear();
      _currentCost = 0;
    }

    CacheL2LRUStrategy(NSUInteger preferredItemCostLimit, NSUInteger preferredItemsTotalCostLimit) : _preferredItemsTotalCostLimit(preferredItemsTotalCostLimit), _preferredItemCostLimit(preferredItemCostLimit)
    {}

    void insertItem(const KeyT &key, const NSUInteger cost)
    {
      _removeItem(key);
      _currentCost += cost;

      if (cost > _preferredItemCostLimit) {
        // put into L2 cache, if the item is too big
        _regularItemsQueueBegin = _costs.insert(_regularItemsQueueBegin, std::make_pair(key,cost));
        _keysToCosts[key] = _regularItemsQueueBegin;
      } else {
        // put into L1 cache
        _costs.push_front(std::make_pair(key,cost));
        _keysToCosts[key] = _costs.begin();

        // maintaining the index, cost tracking for L1
        _preferredItemsCurrentCost += cost;
        _keysToPreferredItemCosts[key] = _costs.begin();

        // automatically compact for L1
        _compactPreferredItemsQueueIfNeeded();
      }
    }

    void moveItemAfterHit(const KeyT &key)
    {
      auto it = _keysToCosts.find(key);
      if (it == _keysToCosts.end()) {
        return;
      }

      NSUInteger cost = it->second->second;
      if (cost > _preferredItemCostLimit) {
        // large items are put in the front of L2
        _costs.splice(_regularItemsQueueBegin, _costs, it->second);
        _regularItemsQueueBegin = it->second;
      } else {
        // small items are put in the front of L1
        auto itL1 = _keysToPreferredItemCosts.find(key);
        if (itL1 == _keysToPreferredItemCosts.end()) {
          _keysToPreferredItemCosts[key] = it->second;
          _preferredItemsCurrentCost += cost;
        }
        if (it->second == _regularItemsQueueBegin) {
          _regularItemsQueueBegin++;
        }
        _costs.splice(_costs.begin(), _costs, it->second);
      }
      _compactPreferredItemsQueueIfNeeded();
    }

    void removeItem(const KeyT &key)
    {
      _removeItem(key);
    }

    std::vector<KeyT> compactWithCost(const NSUInteger costToErase)
    {
      std::vector<KeyT> keysRemoved;
      NSInteger toErase = costToErase;

      auto rit = _costs.rbegin();
      while (toErase > 0 && rit != _costs.rend()) {
        toErase -= rit->second;
        KeyT key = rit->first;
        keysRemoved.push_back(key);
        rit = typename LRUQueue::reverse_iterator(_removeItem(key));
      }

      return keysRemoved;
    }
  };
  /**
   Concrete Cache (with Strategy)
  */
  template <typename KeyT,
  typename ValueT,
  typename Hasher=HashFunctor<KeyT>,
  typename KeyEqual=EqualFunctor<KeyT>,
  template <typename, typename, typename, typename> class CacheStrategy = CacheLRUStrategy>
  class CacheImpl : public Cache<KeyT, ValueT, Hasher, KeyEqual>
  {
      // Types
    typedef Cache<KeyT, ValueT, Hasher, KeyEqual> BaseT;
    static constexpr NSUInteger UNLIMITED_MAX_COST = 0;
    static constexpr CGFloat DEFAULT_COMPACTION_FACTOR = 0.2; // 20%

  private:
    CacheStrategy<KeyT, ValueT, Hasher, KeyEqual> _cacheStrategy;

      // Implementation overrides
    virtual void onClear() override { _cacheStrategy.clear(); }
    virtual void onRemoveItem(KeyT const& key) override { _cacheStrategy.removeItem(key); }
    virtual void onInsertItem(KeyT const& key, NSUInteger cost) override { _cacheStrategy.insertItem(key, cost); }
    virtual void onItemHit(KeyT const& key) override { _cacheStrategy.moveItemAfterHit(key); }
    virtual std::vector<KeyT> onCompact(NSUInteger toEraseCost) override { return _cacheStrategy.compactWithCost(toEraseCost); }
    virtual NSUInteger getCurrentCost() const override { return _cacheStrategy.getCurrentCost(); }
  public:
  template <typename ...StrategyArgs>
    CacheImpl(const std::string &cacheName, NSUInteger maxCost, CGFloat compactionFactor, StrategyArgs&&... args)
      : BaseT(cacheName, maxCost, compactionFactor),
      _cacheStrategy(std::forward<StrategyArgs>(args)...)
    {
    }
    // Default constructor in case strategy can be default constructed
    CacheImpl()
      : CacheImpl(std::string(), UNLIMITED_MAX_COST, DEFAULT_COMPACTION_FACTOR)
    {
    }
  };



  template <typename KeyT,
  typename ValueT,
  typename Hasher=HashFunctor<KeyT>,
  typename KeyEqual=EqualFunctor<KeyT>,
  template <typename, typename, typename, typename> class CacheStrategy = CacheLRUStrategy, class lockPolicy = std::mutex>
  class ConcurrentCacheImpl
  {
  private:
    CacheImpl<KeyT, ValueT, Hasher, KeyEqual, CacheStrategy> _cacheImpl;
    lockPolicy _l;
  public:
    //methods to be used publically
    void compact()
    {
      std::lock_guard<lockPolicy> lg(_l);
      _cacheImpl.compact();
    }

    /** Executes a forced compact based on any given compaction factor. */

    void compact(CGFloat compactionFactor)
    {
      std::lock_guard<lockPolicy> lg(_l);
      _cacheImpl.compact(compactionFactor);
    }

    void insert(const KeyT &key, const ValueT &value, const NSUInteger cost)
    {
      std::lock_guard<lockPolicy> lg(_l);
      _cacheImpl.insert(key, value, cost);
    }

    ValueT find(const KeyT &first, ValueT notFoundValue, bool touch = true)  // not const, since it modifies _costs
    {
      std::lock_guard<lockPolicy> lg(_l);
      return _cacheImpl.find(first, notFoundValue, touch);
    }

    template<
    typename... Dummy,
    typename U = ValueT,
    typename = typename std::enable_if<std::is_pointer<U>::value, void>::type
    >
    ValueT find(const KeyT &first, bool touch = true)  // not const, since it modifies _costs
    {
      std::lock_guard<lockPolicy> lg(_l);
      return _cacheImpl.find(first, touch);
    }
    void removeAllObjects(){
      std::lock_guard<lockPolicy> lg(_l);
      _cacheImpl.removeAllObjects();
    }
    //constructors
    template <typename ...StrategyArgs>
    ConcurrentCacheImpl(StrategyArgs&&... args) : _cacheImpl(std::forward<StrategyArgs>(args)...)
    {
    }
  };
};// end namespace ASDK
