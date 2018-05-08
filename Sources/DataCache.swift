/**
 *  Cachyr
 *
 *  Copyright (c) 2016 NRK. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

/**
 Options indicating which data layers to access when getting/setting a value.
 */
public struct DataCacheAccessOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let disk   = DataCacheAccessOptions(rawValue: 1 << 0)
    public static let memory = DataCacheAccessOptions(rawValue: 1 << 1)

    public static let `default`: DataCacheAccessOptions = [.disk, .memory]
}

/**
 Generic data cache backed by a memory cache and a disk cache.
 */
open class DataCache<ValueType: DataConvertable> {
    /**
     Closure used for completions that have no result.
     */
    public typealias Completion = () -> Void

    /**
     Closure used for completions that have a key/value result.
     */
    public typealias ValueCompletion = (_ value: ValueType?) -> Void

    /**
     Name of cache. The disk cache will use this name for the name of the on-disk directory.
     Reverse DNS notation is preferred.
     */
    public let name: String

    /**
     Direct access to the memory cache. If used, remember that any changes will not be done on the
     data cache access queue and might cause synchronization problems.
     */
    public let memoryCache: MemoryCache<ValueType>

    /**
     Direct access to the disk cache. If used, remember that any changes will not be done on the
     data cache access queue and might cause synchronization problems.
     */
    public let diskCache: DiskCache<ValueType>

    /**
     Serial queue used to synchronize access to the cache.
     */
    private let accessQueue = DispatchQueue(label: "no.nrk.yr.cache.queue")

    /**
     All completion closures are dispatched on this queue.
     */
    private let completionQueue: DispatchQueue

    public init(name: String = "no.nrk.yr.cache", completionQueue: DispatchQueue? = nil, diskBaseURL: URL? = nil) {
        self.name = name
        self.completionQueue = completionQueue ?? DispatchQueue(label: "no.nrk.yr.cache.completion")
        memoryCache = MemoryCache<ValueType>(name: name)
        diskCache = DiskCache<ValueType>(name: name, baseURL: diskBaseURL)
    }

    /**
     Synchronously check if value identified by key exists in cache.
     */
    public func contains(key: String, access: DataCacheAccessOptions = .default) -> Bool {
        return accessQueue.sync {
            return _contains(key: key, access: access)
        }
    }

    /**
     Asynchronously check if value identified by key exists in cache.
     */
    public func contains(key: String, access: DataCacheAccessOptions = .default, completion: @escaping (Bool) -> Void) {
        accessQueue.async {
            let found = self._contains(key: key, access: access)
            self.completionQueue.async {
                completion(found)
            }
        }
    }

    /**
     Directly check if value identified by key exists in cache. Not thread-safe.
     */
    private func _contains(key: String, access: DataCacheAccessOptions = .default) -> Bool {
        var found = false

        if access.contains(.memory) {
            found = memoryCache.contains(key: key)
        }

        if !found, access.contains(.disk) {
            found = diskCache.contains(key: key)
        }

        return found
    }

    /**
     Synchronously fetch value from cache.
     */
    public func value(forKey key: String, access: DataCacheAccessOptions = .default) -> ValueType? {
        return accessQueue.sync {
            return _value(for: key, access: access)
        }
    }

    /**
     Asynchronously fetch value from cache.
     */
    public func value(forKey key: String, access: DataCacheAccessOptions = .default, completion: @escaping ValueCompletion) {
        accessQueue.async {
            let value = self._value(for: key, access: access)
            self.completionQueue.async {
                completion(value)
            }
        }
    }

    /**
     Common synchronous fetch value function. Not thread-safe.
     */
    private func _value(for key: String, access: DataCacheAccessOptions = .default) -> ValueType? {
        if access.contains(.memory) {
            if let value = memoryCache.value(forKey: key) {
                CacheLog.verbose("Value for '\(key)' found in memory cache")
                return value
            }

            CacheLog.verbose("Value for '\(key)' not found in memory cache.")
        }

        if access.contains(.disk) {
            if let value = diskCache.value(forKey: key) {
                let expires = diskCache.expirationDate(forKey: key)
                CacheLog.verbose("Value for '\(key)' found in disk cache, expires '\(self.stringFromDate(expires))'")
                memoryCache.setValue(value, forKey: key, expires: expires)
                return value
            }

            CacheLog.verbose("Value for '\(key)' not found in disk cache.")
        }

        return nil
    }

    /**
     Synchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    public func setValue(_ value: ValueType, forKey key: String, expires: Date? = nil, access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _setValue(value, for: key, expires: expires, access: access)
        }
    }

    /**
     Asynchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    public func setValue(_ value: ValueType, forKey key: String, expires: Date? = nil, access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._setValue(value, for: key, expires: expires, access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common value setter. Not thread-safe.
     */
    private func _setValue(_ value: ValueType, for key: String, expires: Date? = nil, access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.setValue(value, forKey: key, expires: expires)
        }
        if access.contains(.disk) {
            diskCache.setValue(value, forKey: key, expires: expires)
        }
    }

    /**
     Synchronously remove value for key.
     */
    public func removeValue(forKey key: String, access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _removeValue(for: key, access: access)
        }
    }

    /**
     Asynchronously remove value for key.
     */
    public func removeValue(forKey key: String, access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._removeValue(for: key, access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common remove value function. Not thread-safe.
     */
    private func _removeValue(for key: String, access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.removeValue(forKey: key)
        }
        if access.contains(.disk) {
            diskCache.removeValue(forKey: key)
        }
    }

    /**
     Synchronously remove all values in both memory and disk caches.
     */
    public func removeAll(access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _removeAll(access: access)
        }
    }

    /**
     Asynchronously remove all values in both memory and disk caches.
     */
    public func removeAll(access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._removeAll(access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common remove all function. Not thread-safe.
     */
    private func _removeAll(access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.removeAll()
        }
        if access.contains(.disk) {
            diskCache.removeAll()
        }
    }

    /**
     Synchronously remove expired values in both memory and disk caches.
     */
    public func removeExpired(access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _removeExpired(access: access)
        }
    }

    /**
     Asynchronously remove expired values in both memory and disk caches.
     */
    public func removeExpired(access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._removeExpired(access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function that removes expired cache items. Not thread-safe.
     */
    private func _removeExpired(access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.removeExpired()
        }
        if access.contains(.disk) {
            diskCache.removeExpired()
        }
    }

    /**
     Synchronously remove items older than the specified date.
     */
    public func removeItems(olderThan date: Date, access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _removeItems(olderThan: date, access: access)
        }
    }

    /**
     Asynchronously remove items older than the specified date.
     */
    public func removeItems(olderThan date: Date, access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._removeItems(olderThan: date, access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function to remove items older than a specified date. Not thread-safe.
     */
    private func _removeItems(olderThan date: Date, access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.removeItems(olderThan: date)
        }
        if access.contains(.disk) {
            diskCache.removeItems(olderThan: date)
        }
    }

    /**
     Synchronously get expiration date for item identified by key.
     */
    public func expirationDate(forKey key: String, access: DataCacheAccessOptions = .default) -> Date? {
        var date: Date? = nil
        accessQueue.sync {
            date = _expirationDate(for: key, access: access)
        }
        return date
    }

    /**
     Asynchronously get expiration date for item identified by key.
     */
    public func expirationDate(forKey key: String, access: DataCacheAccessOptions = .default, completion: @escaping (Date?) -> Void) {
        accessQueue.async {
            let date = self._expirationDate(for: key, access: access)
            self.completionQueue.async {
                completion(date)
            }
        }
    }

    /**
     Private common function to get expiration date for item identified by key. Not thread-safe.
     */
    private func _expirationDate(for key: String, access: DataCacheAccessOptions = .default) -> Date? {
        if access.contains(.memory), let expires = memoryCache.expirationDate(forKey: key) {
            return expires
        }

        if access.contains(.disk) {
            return diskCache.expirationDate(forKey: key)
        }

        return nil
    }

    /**
     Synchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    public func setExpirationDate(_ date: Date?, forKey key: String, access: DataCacheAccessOptions = .default) {
        accessQueue.sync {
            _setExpirationDate(date, for: key, access: access)
        }
    }

    /**
     Asynchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    public func setExpirationDate(_ date: Date?, forKey key: String, access: DataCacheAccessOptions = .default, completion: @escaping Completion) {
        accessQueue.async {
            self._setExpirationDate(date, for: key, access: access)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function to set expiration date for item identified by key. Not thread-safe.
     */
    private func _setExpirationDate(_ date: Date?, for key: String, access: DataCacheAccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.setExpirationDate(date, forKey: key)
        }
        if access.contains(.disk) {
            diskCache.setExpirationDate(date, forKey: key)
        }
    }

    /**
     Private debug date to string function
     */
    private func stringFromDate(_ date: Date?) -> String {
        if let date = date {
            return "\(date)"
        }
        return ""
    }
}
