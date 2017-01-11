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
     Synchronously fetch value from cache. Will not query data source if value is not found.
     */
    open func value<ValueType: DataConvertable>(for key: String) -> ValueType? {
        var value: ValueType? = nil
        accessQueue.sync {
            value = _value(for: key)
        }

        return value
    }

    /**
     Fetch value from cache. If a data source has been set it will be queried when a value is not found.
     */
    open func value<ValueType: DataConvertable>(for key: String, completion: @escaping ValueCompletion<ValueType>) {
        accessQueue.async {
            // Check if key is waiting for data source to populate cache
            if self.isKeyWaiting(key) {
                self.addDeferredCompletion(completion, for: key)
                return
            }

            if let value: ValueType = self._value(for: key) {
                self.completionQueue.async {
                    completion(value)
                }
                return
            }

            guard let dataSource = self.dataSource else {
                CacheLog.verbose("Value for '\(key)' not found in data cache.")
                self.completionQueue.async {
                    completion(nil)
                }
                return
            }

            CacheLog.verbose("Looking for '\(key)' in data source.")

            // Add current completion to data source completion queue
            self.addDeferredCompletion(completion, for: key)

            dataSource.data(for: key) { [weak self] (data, expiration) in
                guard let strongSelf = self else { return }

                strongSelf.accessQueue.async {
                    var value: Any? = nil
                    if let data = data {
                        CacheLog.verbose("Value for '\(key)' found in data source.")

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
    }

    /**
     Common synchronous fetch value function. Not thread safe, and will not use data source.
     */
    private func _value<ValueType: DataConvertable>(for key: String) -> ValueType? {
        if let value: ValueType = self.memoryCache.value(for: key) {
            CacheLog.verbose("Value for '\(key)' found in memory cache")
            return value
        }

        CacheLog.verbose("Value for '\(key)' not found in memory cache, checking disk cache.")

        if let value: ValueType = self.diskCache.value(for: key) {
            CacheLog.verbose("Value for '\(key)' found in disk cache.")
            self.memoryCache.setValue(value, for: key)
            return value
        }

        CacheLog.verbose("Value for '\(key)' not found in disk cache.")

        return nil
    }

    /**
     Synchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    open func setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil) {
        accessQueue.sync {
            _setValue(value, for: key, expires: expires)
        }
    }

    /**
     Asynchronously set value for key in both memory and disk caches, with optional expiration date.
     */
    open func setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil, completion: @escaping Completion) {
        accessQueue.async {
            self._setValue(value, for: key, expires: expires)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common value setter. Not thread-safe.
     */
    private func _setValue<ValueType: DataConvertable>(_ value: ValueType, for key: String, expires: Date? = nil) {
        memoryCache.setValue(value, for: key, expires: expires)
        diskCache.setValue(value, for: key, expires: expires)
    }

    /**
     Synchronously remove value for key.
     */
    open func removeValue(for key: String) {
        accessQueue.sync {
            _removeValue(for: key)
        }
    }

    /**
     Asynchronously remove value for key.
     */
    open func removeValue(for key: String, completion: @escaping Completion) {
        accessQueue.async {
            self._removeValue(for: key)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common remove value function. Not thread-safe.
     */
    private func _removeValue(for key: String) {
        memoryCache.removeValue(for: key)
        diskCache.removeValue(for: key)
    }

    /**
     Synchronously remove all values in both memory and disk caches.
     */
    open func removeAll() {
        accessQueue.sync {
            _removeAll()
        }
    }

    /**
     Asynchronously remove all values in both memory and disk caches.
     */
    open func removeAll(completion: @escaping Completion) {
        accessQueue.async {
            self._removeAll()
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common remove all function. Not thread-safe.
     */
    private func _removeAll() {
        memoryCache.removeAll()
        diskCache.removeAll()
    }

    /**
     Synchronously remove expired values in both memory and disk caches.
     */
    open func removeExpired() {
        accessQueue.sync {
            _removeExpired()
        }
    }

    /**
     Asynchronously remove expired values in both memory and disk caches.
     */
    open func removeExpired(completion: @escaping Completion) {
        accessQueue.async {
            self._removeExpired()
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function that removes expired cache items. Not thread-safe.
     */
    private func _removeExpired() {
        memoryCache.removeExpired()
        diskCache.removeExpired()
    }

    /**
     Synchronously remove items older than the specified date.
     */
    open func removeItems(olderThan date: Date) {
        accessQueue.sync {
            _removeItems(olderThan: date)
        }
    }

    /**
     Asynchronously remove items older than the specified date.
     */
    open func removeItems(olderThan date: Date, completion: @escaping Completion) {
        accessQueue.async {
            self._removeItems(olderThan: date)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function to remove items older than a specified date. Not thread-safe.
     */
    private func _removeItems(olderThan date: Date) {
        memoryCache.removeItems(olderThan: date)
        diskCache.removeItems(olderThan: date)
    }

    /**
     Synchronously get expiration date for item identified by key.
     */
    open func expirationDate(for key: String) -> Date? {
        var date: Date? = nil
        accessQueue.sync {
            date = _expirationDate(for: key)
        }
        return date
    }

    /**
     Asynchronously get expiration date for item identified by key.
     */
    open func expirationDate(for key: String, completion: @escaping (Date?) -> Void) {
        accessQueue.async {
            let date = self._expirationDate(for: key)
            self.completionQueue.async {
                completion(date)
            }
        }
    }

    /**
     Private common function to get expiration date for item identified by key. Not thread-safe.
     */
    private func _expirationDate(for key: String) -> Date? {
        if let expires = memoryCache.expirationDate(for: key) {
            return expires
        }
        return diskCache.expirationDate(for: key)
    }

    /**
     Synchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    open func setExpirationDate(_ date: Date?, for key: String) {
        accessQueue.sync {
            _setExpirationDate(date, for: key)
        }
    }

    /**
     Asynchronously set expiration date for item identified by key.
     Set expiration date to nil to remove it.
     */
    open func setExpirationDate(_ date: Date?, for key: String, completion: @escaping Completion) {
        accessQueue.async {
            self._setExpirationDate(date, for: key)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function to set expiration date for item identified by key. Not thread-safe.
     */
    private func _setExpirationDate(_ date: Date?, for key: String) {
        memoryCache.setExpirationDate(date, for: key)
        diskCache.setExpirationDate(date, for: key)
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
