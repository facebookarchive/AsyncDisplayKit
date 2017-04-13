//
//  ASThread.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <assert.h>
#import <pthread.h>
#import <stdbool.h>
#import <stdlib.h>

#import <libkern/OSAtomic.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASBaseDefines.h>


static inline BOOL ASDisplayNodeThreadIsMain()
{
  return 0 != pthread_main_np();
}

#ifdef __cplusplus

#define TIME_LOCKER 0
/**
 * Enable this flag to collect information on the owning thread and ownership level of a mutex.
 * These properties are useful to determine if a mutext has been acquired and in case of a recursive mutex, how many times that happened.
 * 
 * This flag also enable locking assertions (e.g ASDisplayNodeAssertLockUnownedByCurrentThread(node)).
 * The assertions are useful when you want to indicate and enforce the locking policy/expectation of methods.
 * To determine when and which methods acquired a (recursive) mutex (to debug deadlocks, for example),
 * put breakpoints at some assertions. When the breakpoints hit, walk through stack trace frames 
 * and check ownership count of the mutex.
 */
#define CHECK_LOCKING_SAFETY 0

#if TIME_LOCKER
#import <QuartzCore/QuartzCore.h>
#endif

#include <memory>

/**
 For use with ASDN::StaticMutex only.
 */
#define ASDISPLAYNODE_MUTEX_INITIALIZER {PTHREAD_MUTEX_INITIALIZER}
#define ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER {PTHREAD_RECURSIVE_MUTEX_INITIALIZER}

// This MUST always execute, even when assertions are disabled. Otherwise all lock operations become no-ops!
// (To be explicit, do not turn this into an NSAssert, assert(), or any other kind of statement where the
// evaluation of x_ can be compiled out.)
#define ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(x_) do { \
  _Pragma("clang diagnostic push"); \
  _Pragma("clang diagnostic ignored \"-Wunused-variable\""); \
  volatile int res = (x_); \
  assert(res == 0); \
  _Pragma("clang diagnostic pop"); \
} while (0)

/**
 * Assert if the current thread owns a mutex.
 * This assertion is useful when you want to indicate and enforce the locking policy/expectation of methods.
 * To determine when and which methods acquired a (recursive) mutex (to debug deadlocks, for example),
 * put breakpoints at some of these assertions. When the breakpoints hit, walk through stack trace frames
 * and check ownership count of the mutex.
 */
#if CHECK_LOCKING_SAFETY
#define ASDisplayNodeAssertLockUnownedByCurrentThread(lock) ASDisplayNodeAssertFalse(lock.ownedByCurrentThread())
#else
#define ASDisplayNodeAssertLockUnownedByCurrentThread(lock)
#endif

namespace ASDN {
  
  template<class T>
  class Locker
  {
    T &_l;

#if TIME_LOCKER
    CFTimeInterval _ti;
    const char *_name;
#endif

  public:
#if !TIME_LOCKER

    Locker (T &l) ASDISPLAYNODE_NOTHROW : _l (l) {
      _l.lock ();
    }

    ~Locker () {
      _l.unlock ();
    }

    // non-copyable.
    Locker(const Locker<T>&) = delete;
    Locker &operator=(const Locker<T>&) = delete;

#else

    Locker (T &l, const char *name = NULL) ASDISPLAYNODE_NOTHROW : _l (l), _name(name) {
      _ti = CACurrentMediaTime();
      _l.lock ();
    }

    ~Locker () {
      _l.unlock ();
      if (_name) {
        printf(_name, NULL);
        printf(" dt:%f\n", CACurrentMediaTime() - _ti);
      }
    }

#endif

  };

  template<class T>
  class SharedLocker
  {
    std::shared_ptr<T> _l;
    
#if TIME_LOCKER
    CFTimeInterval _ti;
    const char *_name;
#endif
    
  public:
#if !TIME_LOCKER
    
    SharedLocker (std::shared_ptr<T> const& l) ASDISPLAYNODE_NOTHROW : _l (l) {
      assert(_l != nullptr);
      _l->lock ();
    }
    
    ~SharedLocker () {
      _l->unlock ();
    }
    
    // non-copyable.
    SharedLocker(const SharedLocker<T>&) = delete;
    SharedLocker &operator=(const SharedLocker<T>&) = delete;
    
#else
    
    SharedLocker (std::shared_ptr<T> const& l, const char *name = NULL) ASDISPLAYNODE_NOTHROW : _l (l), _name(name) {
      _ti = CACurrentMediaTime();
      _l->lock ();
    }
    
    ~SharedLocker () {
      _l->unlock ();
      if (_name) {
        printf(_name, NULL);
        printf(" dt:%f\n", CACurrentMediaTime() - _ti);
      }
    }
    
#endif
    
  };

  template<class T>
  class Unlocker
  {
    T &_l;
  public:
    Unlocker (T &l) ASDISPLAYNODE_NOTHROW : _l (l) { _l.unlock (); }
    ~Unlocker () {_l.lock ();}
    Unlocker(Unlocker<T>&) = delete;
    Unlocker &operator=(Unlocker<T>&) = delete;
  };
  
  template<class T>
  class SharedUnlocker
  {
    std::shared_ptr<T> _l;
  public:
    SharedUnlocker (std::shared_ptr<T> const& l) ASDISPLAYNODE_NOTHROW : _l (l) { _l->unlock (); }
    ~SharedUnlocker () { _l->lock (); }
    SharedUnlocker(SharedUnlocker<T>&) = delete;
    SharedUnlocker &operator=(SharedUnlocker<T>&) = delete;
  };

  struct Mutex
  {
    /// Constructs a non-recursive mutex (the default).
    Mutex () : Mutex (false) {}

    ~Mutex () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_destroy (&_m));
#if CHECK_LOCKING_SAFETY
      _owner = 0;
      _count = 0;
#endif
    }

    Mutex (const Mutex&) = delete;
    Mutex &operator=(const Mutex&) = delete;

    void lock () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_lock (this->mutex()));
#if CHECK_LOCKING_SAFETY
      mach_port_t thread_id = pthread_mach_thread_np(pthread_self());
      if (thread_id != _owner) {
        // New owner. Since this mutex can't be acquired by another thread if there is an existing owner, _owner and _count must be 0.
        assert(0 == _owner);
        assert(0 == _count);
        _owner = thread_id;
      } else {
        // Existing owner tries to reacquire this (recursive) mutex. _count must already be positive.
        assert(_count > 0);
      }
      ++_count;
#endif
    }

    void unlock () {
#if CHECK_LOCKING_SAFETY
      mach_port_t thread_id = pthread_mach_thread_np(pthread_self());
      // Unlocking a mutex on an unowning thread causes undefined behaviour. Assert and fail early.
      assert(thread_id == _owner);
      // Current thread owns this mutex. _count must be positive.
      assert(_count > 0);
      --_count;
      if (0 == _count) {
        // Current thread is no longer the owner.
        _owner = 0;
      }
#endif
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_unlock (this->mutex()));
    }

    pthread_mutex_t *mutex () { return &_m; }

#if CHECK_LOCKING_SAFETY
    bool ownedByCurrentThread() {
      return _count > 0 && pthread_mach_thread_np(pthread_self()) == _owner;
    }
#endif
    
  protected:
    explicit Mutex (bool recursive) {
      if (!recursive) {
        ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_init (&_m, NULL));
      } else {
        pthread_mutexattr_t attr;
        ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutexattr_init (&attr));
        ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE));
        ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_init (&_m, &attr));
        ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutexattr_destroy (&attr));
      }
#if CHECK_LOCKING_SAFETY
      _owner = 0;
      _count = 0;
#endif
    }

  private:
    pthread_mutex_t _m;
#if CHECK_LOCKING_SAFETY
    mach_port_t _owner;
    uint32_t _count;
#endif
  };

  /**
   Obj-C doesn't allow you to pass parameters to C++ ivar constructors.
   Provide a convenience to change the default from non-recursive to recursive.

   But wait! Recursive mutexes are a bad idea. Think twice before using one:

   http://www.zaval.org/resources/library/butenhof1.html
   http://www.fieryrobot.com/blog/2008/10/14/recursive-locks-will-kill-you/
   */
  struct RecursiveMutex : Mutex
  {
    RecursiveMutex () : Mutex (true) {}
  };

  typedef Locker<Mutex> MutexLocker;
  typedef SharedLocker<Mutex> MutexSharedLocker;
  typedef Unlocker<Mutex> MutexUnlocker;
  typedef SharedUnlocker<Mutex> MutexSharedUnlocker;

  /**
   If you are creating a static mutex, use StaticMutex and specify its default value as one of ASDISPLAYNODE_MUTEX_INITIALIZER
   or ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER. This avoids expensive constructor overhead at startup (or worse, ordering
   issues between different static objects). It also avoids running a destructor on app exit time (needless expense).

   Note that you can, but should not, use StaticMutex for non-static objects. It will leak its mutex on destruction,
   so avoid that!

   If you fail to specify a default value (like ASDISPLAYNODE_MUTEX_INITIALIZER) an assert will be thrown when you attempt to lock.
   */
  struct StaticMutex
  {
    pthread_mutex_t _m; // public so it can be provided by ASDISPLAYNODE_MUTEX_INITIALIZER and friends

    void lock () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_lock (this->mutex()));
    }

    void unlock () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_mutex_unlock (this->mutex()));
    }

    pthread_mutex_t *mutex () { return &_m; }

    StaticMutex(const StaticMutex&) = delete;
    StaticMutex &operator=(const StaticMutex&) = delete;
  };

  typedef Locker<StaticMutex> StaticMutexLocker;
  typedef Unlocker<StaticMutex> StaticMutexUnlocker;

  struct Condition
  {
    Condition () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_cond_init(&_c, NULL));
    }

    ~Condition () {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_cond_destroy(&_c));
    }

    // non-copyable.
    Condition(const Condition&) = delete;
    Condition &operator=(const Condition&) = delete;

    void signal() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_cond_signal(&_c));
    }

    void wait(Mutex &m) {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_cond_wait(&_c, m.mutex()));
    }

    pthread_cond_t *condition () {
      return &_c;
    }

  private:
    pthread_cond_t _c;
  };

  struct ReadWriteLock
  {
    ReadWriteLock() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_rwlock_init(&_rwlock, NULL));
    }

    ~ReadWriteLock() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_rwlock_destroy(&_rwlock));
    }

    // non-copyable.
    ReadWriteLock(const ReadWriteLock&) = delete;
    ReadWriteLock &operator=(const ReadWriteLock&) = delete;

    void readlock() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&_rwlock));
    }

    void writelock() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&_rwlock));
    }

    void unlock() {
      ASDISPLAYNODE_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&_rwlock));
    }

  private:
    pthread_rwlock_t _rwlock;
  };

  class ReadWriteLockReadLocker
  {
    ReadWriteLock &_lock;
  public:
    ReadWriteLockReadLocker(ReadWriteLock &lock) ASDISPLAYNODE_NOTHROW : _lock(lock) {
      _lock.readlock();
    }

    ~ReadWriteLockReadLocker() {
      _lock.unlock();
    }

    // non-copyable.
    ReadWriteLockReadLocker(const ReadWriteLockReadLocker&) = delete;
    ReadWriteLockReadLocker &operator=(const ReadWriteLockReadLocker&) = delete;
  };

  class ReadWriteLockWriteLocker
  {
    ReadWriteLock &_lock;
  public:
    ReadWriteLockWriteLocker(ReadWriteLock &lock) ASDISPLAYNODE_NOTHROW : _lock(lock) {
      _lock.writelock();
    }

    ~ReadWriteLockWriteLocker() {
      _lock.unlock();
    }

    // non-copyable.
    ReadWriteLockWriteLocker(const ReadWriteLockWriteLocker&) = delete;
    ReadWriteLockWriteLocker &operator=(const ReadWriteLockWriteLocker&) = delete;
  };

} // namespace ASDN

#endif /* __cplusplus */
