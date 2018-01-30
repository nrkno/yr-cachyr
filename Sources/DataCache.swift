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

fileprivate protocol DeferredCompletionWrapper {
    func complete(with value: Any?)
}

fileprivate class DeferredCompletion<ValueType: DataConvertable>: DeferredCompletionWrapper {
    let completion: DataCache.ValueCompletion<ValueType>

    init(completion: @escaping DataCache.ValueCompletion<ValueType>) {
        self.completion = completion
    }

    func complete(with value: Any?) {
        completion(value as? ValueType)
    }
}

open class DataCache {
    /**
     Closure used for completions that have no result.
     */
    public typealias Completion = () -> Void

    /**
     Closure used for completions that have a key/value result.
     */
    public typealias ValueCompletion<Value: DataConvertable> = (_ value: Value?) -> Void

    /**
     Options indicating which data layers to access when getting/setting a value.
     */
    public struct AccessOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let disk       = AccessOptions(rawValue: 1 << 0)
        public static let memory     = AccessOptions(rawValue: 1 << 1)
        public static let dataSource = AccessOptions(rawValue: 1 << 2)

        public static let `default`: AccessOptions = [.disk, .memory, .dataSource]
    }

    /**
     Name of cache. The disk cache will use this name for the name of the on-disk directory.
     Reverse DNS notation is preferred.
     */
    public let name: String

    /**
     Direct access to the memory cache. If used, remember that any changes will not be done on the
     data cache access queue and might cause synchronization problems.
     */
    public let memoryCache: MemoryCache

    /**
     Direct access to the disk cache. If used, remember that any changes will not be done on the
     data cache access queue and might cause synchronization problems.
     */
    public let diskCache: DiskCache

    /**
     Data source which will be queried for data if none is found in disk cache.
     */
    public var dataSource: CacheDataSource?

    /**
     Serial queue used to synchronize access to the cache.
     */
    private let accessQueue = DispatchQueue(label: "no.nrk.yr.cache.queue")

    /**
     All completion closures are dispatched on this queue.
     */
    private let completionQueue: DispatchQueue

    /**
     Completions waiting for data source to populate cache.
     */
    private var waitingCompletions = [String: [DeferredCompletionWrapper]]()

    public init(name: String = "no.nrk.yr.cache", completionQueue: DispatchQueue = DispatchQueue.global(qos: .background), diskBaseURL: URL? = nil) {
        self.name = name
        self.completionQueue = completionQueue
        memoryCache = MemoryCache(name: name)
        diskCache = DiskCache(name: name, baseURL: diskBaseURL)
    }

    /**
     Synchronously check if value identified by key exists in cache.
     */
    open func contains(key: String, access: AccessOptions = .default) -> Bool {
        var found = false
        accessQueue.sync {
            found = _contains(key: key, access: access)
        }

        return found
    }

    /**
     Asynchronously check if value identified by key exists in cache.
     */
    open func contains(key: String, access: AccessOptions = .default, completion: @escaping (Bool) -> Void) {
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
    private func _contains(key: String, access: AccessOptions = .default) -> Bool {
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
     Synchronously fetch value from cache. Will not query data source if value is not found.
     */
    open func value<ValueType: DataConvertable>(for key: String, access: AccessOptions = .default) -> ValueType? {
        var value: ValueType? = nil
        accessQueue.sync {
            value = _value(for: key, access: access)
        }

        return value
    }

    /**
     Fetch value from cache. If a data source has been set it will be queried when a value is not found.
     */
    @discardableResult
    open func value<ValueType: DataConvertable>(for key: String, access: AccessOptions = .default, completion: @escaping ValueCompletion<ValueType>) -> Any? {

        var dataSourceClientData: Any? = nil

        accessQueue.sync {
            // Check if key is waiting for data source to populate cache
            if self.isKeyWaiting(key) {
                self.addDeferredCompletion(completion, for: key)
                return
            }

            if let value: ValueType = self._value(for: key, access: access) {
                self.completionQueue.async {
                    completion(value)
                }
                return
            }

            guard access.contains(.dataSource), let dataSource = self.dataSource else {
                CacheLog.verbose("Value for '\(key)' not found in data cache.")
                self.completionQueue.async {
                    completion(nil)
                }
                return
            }

            CacheLog.verbose("Looking for '\(key)' in data source.")

            // Add current completion to data source completion queue
            self.addDeferredCompletion(completion, for: key)

            dataSourceClientData = dataSource.data(for: key) { [weak self] (data, expiration) in
                guard let strongSelf = self else { return }

                strongSelf.accessQueue.async {
                    var value: Any? = nil
                    if let data = data {
                        CacheLog.verbose("Value for '\(key)' found in data source, expires '\(strongSelf.stringFromDate(expiration))'")

                        strongSelf.diskCache.setValue(data, for: key, expires: expiration)
                        CacheLog.verbose("Value for '\(key)' written to disk cache")

                        // The value of the current type isn't necessarily what the deferred
                        // completions want, but it probably is and will save time, and populating
                        // the memory cache is inexpensive at this point.
                        value = ValueType.value(from: data)
                        if let value = value as? ValueType {
                            strongSelf.memoryCache.setValue(value, for: key, expires: expiration)
                            CacheLog.verbose("Value for '\(key)' written to memory cache.")
                        }
                    }
                    else {
                        CacheLog.verbose("Value for '\(key)' not found in datasource")
                    }

                    // Perform all waiting completions
                    strongSelf.performDeferredCompletions(for: key, value: value)
                }
            }
        }

        return dataSourceClientData
    }

    /**
     Common synchronous fetch value function. Not thread safe, and will not use data source.
     */
    private func _value<ValueType: DataConvertable>(for key: String, access: AccessOptions = .default) -> ValueType? {
        if access.contains(.memory) {
            if let value: ValueType = self.memoryCache.value(for: key) {
                CacheLog.verbose("Value for '\(key)' found in memory cache")
                return value
            }

            CacheLog.verbose("Value for '\(key)' not found in memory cache.")
        }

        if access.contains(.disk) {
            if let value: ValueType = self.diskCache.value(for: key) {
                let expires = self.diskCache.expirationDate(for: key)
                CacheLog.verbose("Value for '\(key)' found in disk cache, expires '\(self.stringFromDate(expires))'")
                self.memoryCache.setValue(value, for: key, expires: expires)
                return value
            }

            CacheLog.verbose("Value for '\(key)' not found in disk cache.")
        }

        return nil
    }

    /**
     Synchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    open func setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil, access: AccessOptions = .default) {
        accessQueue.sync {
            _setValue(value, for: key, expires: expires, access: access)
        }
    }

    /**
     Asynchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    open func setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil, access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil, access: AccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.setValue(value, for: key, expires: expires)
        }
        if access.contains(.disk) {
            diskCache.setValue(value, for: key, expires: expires)
        }
    }

    /**
     Synchronously remove value for key.
     */
    open func removeValue(for key: String, access: AccessOptions = .default) {
        accessQueue.sync {
            _removeValue(for: key, access: access)
        }
    }

    /**
     Asynchronously remove value for key.
     */
    open func removeValue(for key: String, access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _removeValue(for key: String, access: AccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.removeValue(for: key)
        }
        if access.contains(.disk) {
            diskCache.removeValue(for: key)
        }
    }

    /**
     Synchronously remove all values in both memory and disk caches.
     */
    open func removeAll(access: AccessOptions = .default) {
        accessQueue.sync {
            _removeAll(access: access)
        }
    }

    /**
     Asynchronously remove all values in both memory and disk caches.
     */
    open func removeAll(access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _removeAll(access: AccessOptions = .default) {
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
    open func removeExpired(access: AccessOptions = .default) {
        accessQueue.sync {
            _removeExpired(access: access)
        }
    }

    /**
     Asynchronously remove expired values in both memory and disk caches.
     */
    open func removeExpired(access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _removeExpired(access: AccessOptions = .default) {
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
    open func removeItems(olderThan date: Date, access: AccessOptions = .default) {
        accessQueue.sync {
            _removeItems(olderThan: date, access: access)
        }
    }

    /**
     Asynchronously remove items older than the specified date.
     */
    open func removeItems(olderThan date: Date, access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _removeItems(olderThan date: Date, access: AccessOptions = .default) {
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
    open func expirationDate(for key: String, access: AccessOptions = .default) -> Date? {
        var date: Date? = nil
        accessQueue.sync {
            date = _expirationDate(for: key, access: access)
        }
        return date
    }

    /**
     Asynchronously get expiration date for item identified by key.
     */
    open func expirationDate(for key: String, access: AccessOptions = .default, completion: @escaping (Date?) -> Void) {
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
    private func _expirationDate(for key: String, access: AccessOptions = .default) -> Date? {
        if access.contains(.memory), let expires = memoryCache.expirationDate(for: key) {
            return expires
        }

        if access.contains(.disk) {
            return diskCache.expirationDate(for: key)
        }

        return nil
    }

    /**
     Synchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    open func setExpirationDate(_ date: Date?, for key: String, access: AccessOptions = .default) {
        accessQueue.sync {
            _setExpirationDate(date, for: key, access: access)
        }
    }

    /**
     Asynchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    open func setExpirationDate(_ date: Date?, for key: String, access: AccessOptions = .default, completion: @escaping Completion) {
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
    private func _setExpirationDate(_ date: Date?, for key: String, access: AccessOptions = .default) {
        if access.contains(.memory) {
            memoryCache.setExpirationDate(date, for: key)
        }
        if access.contains(.disk) {
            diskCache.setExpirationDate(date, for: key)
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

    private func addDeferredCompletion<ValueType: DataConvertable>(_ completion: @escaping ValueCompletion<ValueType>, for key: String) {
        let wrapper = DeferredCompletion(completion: completion)
        if var completions = waitingCompletions[key] {
            completions.append(wrapper)
            waitingCompletions[key] = completions
        } else {
            waitingCompletions[key] = [wrapper]
        }
        CacheLog.verbose("Key \(key) queued for deferred completion.")
    }

    private func performDeferredCompletions(for key: String, value: Any?) {
        guard let wrappers = waitingCompletions[key] else { return }
        for wrapper in wrappers {
            completionQueue.async {
                wrapper.complete(with: value)
            }
        }
        waitingCompletions[key] = nil
    }

    private func isKeyWaiting(_ key: String) -> Bool {
        var mustWait = false
        if let completions = waitingCompletions[key], !completions.isEmpty {
            mustWait = true
            CacheLog.verbose("'\(key)' is waiting for data source, completion enqueued.")
        }

        return mustWait
    }
}
