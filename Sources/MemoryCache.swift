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

private final class ValueWrapper {
    let created: Date
    var expiration: Date?
    let value: Any

    init(value: Any, expiration: Date? = nil) {
        self.created = Date()
        self.expiration = expiration
        self.value = value
    }
}

open class MemoryCache {
    public let name: String

    /**
     NSCache does not support enumeration of the keys and objects it contains. The access queue
     is used to synchronize access to a set with keys.
     */
    private let accessQueue = DispatchQueue(label: "no.nrk.yr.cache.memory")

    private let cache = NSCache<NSString, ValueWrapper>()

    public private(set) var keys = Set<String>()

    public var checkExpiredInterval: TimeInterval = 10 * 60

    public var isCheckExpiredIntervalDone: Bool {
        return (Date().timeIntervalSince1970 - lastRemoveExpired.timeIntervalSince1970) > checkExpiredInterval
    }

    public private(set) var lastRemoveExpired = Date(timeIntervalSince1970: 0)

    public init(name: String = "no.nrk.yr.cache.memory") {
        self.name = name
    }

    public func value<ValueType>(for key: String) -> ValueType? {
        var foundValue: ValueType? = nil
        accessQueue.sync {
            removeExpiredAfterInterval()

            guard let wrapper = wrapper(for: key) else {
                return
            }

            if hasExpired(wrapper: wrapper) {
                removeValueNoSync(for: key)
                return
            }

            foundValue = wrapper.value as? ValueType
        }
        return foundValue
    }

    public func setValue<ValueType>(_ value: ValueType, for key: String, expires: Date? = nil) {
        accessQueue.sync {
            removeExpiredAfterInterval()
            addValue(value, for: key, expires: expires)
        }
    }

    public func removeValue(for key: String) {
        accessQueue.sync {
            removeValueNoSync(for: key)
        }
    }

    public func removeAll() {
        accessQueue.sync {
            cache.removeAllObjects()
            keys.removeAll()
        }
    }

    public func removeExpired() {
        accessQueue.sync {
            removeExpiredItems()
        }
    }

    public func expirationDate(for key: String) -> Date? {
        var date: Date? = nil
        accessQueue.sync {
            if let wrapper = wrapper(for: key) {
                date = wrapper.expiration
            }
        }
        return date
    }

    public func setExpirationDate(_ date: Date?, for key: String) {
        accessQueue.sync {
            if let wrapper = wrapper(for: key) {
                wrapper.expiration = date
            }
        }
    }

    public func removeItems(olderThan date: Date) {
        accessQueue.sync {
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

    private func wrapper(for key: String) -> ValueWrapper? {
        return cache.object(forKey: key as NSString)
    }

    private func addValue<ValueType>(_ value: ValueType, for key: String, expires: Date? = nil) {
        let wrapper = ValueWrapper(value: value, expiration: expires)
        cache.setObject(wrapper, forKey: key as NSString)
        keys.insert(key)
    }

    private func removeValueNoSync(for key: String) {
        keys.remove(key)
        cache.removeObject(forKey: key as NSString)
    }

    private func hasExpired(wrapper: ValueWrapper) -> Bool {
        guard let expireDate = wrapper.expiration else { return false }
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
        if !isCheckExpiredIntervalDone {
            return
        }
        removeExpiredItems()
    }
}
