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

private final class ValueWrapper<ValueType> {
    let created: Date
    var expiration: Date?
    let value: ValueType

    init(value: ValueType, expiration: Date? = nil) {
        self.created = Date()
        self.expiration = expiration
        self.value = value
    }
}

open class MemoryCache<ValueType> {
    public let name: String

    /**
     NSCache does not support enumeration of the keys and objects it contains. The access queue
     is used to synchronize access to a set with keys.
     */
    private let accessQueue = DispatchQueue(label: "no.nrk.yr.cache.memory", attributes: .concurrent)

    private let cache = NSCache<NSString, ValueWrapper<ValueType>>()

    public private(set) var keys = Set<String>()

    public var checkExpiredInterval: TimeInterval = 10 * 60

    public var shouldCheckExpired: Bool {
        return (Date().timeIntervalSince1970 - lastRemoveExpired.timeIntervalSince1970) > checkExpiredInterval
    }

    public private(set) var lastRemoveExpired = Date(timeIntervalSince1970: 0)

    public init(name: String = "no.nrk.yr.cache.memory") {
        self.name = name
    }

    public func contains(key: String) -> Bool {
        return accessQueue.sync {
            return keys.contains(key)
        }
    }

    public func value(forKey key: String) -> ValueType? {
        return accessQueue.sync {
            guard let wrapper = wrapper(for: key) else {
                return nil
            }

            if hasExpired(wrapper: wrapper) {
                accessQueue.async(flags: .barrier) {
                    self.removeValueNoSync(for: key)
                }
                return nil
            }

            return wrapper.value
        }
    }

    public func setValue(_ value: ValueType, forKey key: String, expires: Date? = nil) {
        accessQueue.sync(flags: .barrier) {
            removeExpiredAfterInterval()
            addValue(value, for: key, expires: expires)
        }
    }

    public func removeValue(forKey key: String) {
        accessQueue.sync(flags: .barrier) {
            removeValueNoSync(for: key)
        }
    }

    public func removeAll() {
        accessQueue.sync(flags: .barrier) {
            cache.removeAllObjects()
            keys.removeAll()
        }
    }

    public func removeExpired() {
        accessQueue.sync(flags: .barrier) {
            removeExpiredItems()
        }
    }

    public func expirationDate(forKey key: String) -> Date? {
        return accessQueue.sync {
            if let wrapper = wrapper(for: key) {
                return wrapper.expiration
            }
            return nil
        }
    }

    public func setExpirationDate(_ date: Date?, forKey key: String) {
        accessQueue.sync(flags: .barrier) {
            if let wrapper = wrapper(for: key) {
                wrapper.expiration = date
            }
        }
    }

    public func removeItems(olderThan date: Date) {
        accessQueue.sync(flags: .barrier) {
            for key in keys {
                guard let wrapper = wrapper(for: key) else {
                    keys.remove(key)
                    continue
                }
                if wrapper.created <= date {
                    removeValueNoSync(for: key)
                }
            }
        }
    }

    private func wrapper(for key: String) -> ValueWrapper<ValueType>? {
        return cache.object(forKey: key as NSString)
    }

    private func addValue(_ value: ValueType, for key: String, expires: Date? = nil) {
        let wrapper = ValueWrapper(value: value, expiration: expires)
        cache.setObject(wrapper, forKey: key as NSString)
        keys.insert(key)
    }

    private func removeValueNoSync(for key: String) {
        keys.remove(key)
        cache.removeObject(forKey: key as NSString)
    }

    private func hasExpired(wrapper: ValueWrapper<ValueType>) -> Bool {
        guard let expireDate = wrapper.expiration else {
            return false
        }
        return expireDate < Date()
    }

    private func removeExpiredItems() {
        for key in keys {
            guard let wrapper = wrapper(for: key) else {
                keys.remove(key)
                continue
            }
            if hasExpired(wrapper: wrapper) {
                removeValueNoSync(for: key)
            }
        }
        lastRemoveExpired = Date()
    }

    private func removeExpiredAfterInterval() {
        if !shouldCheckExpired {
            return
        }
        removeExpiredItems()
    }
}
