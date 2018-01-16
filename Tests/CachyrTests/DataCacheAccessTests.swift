/**
 *  Cachyr
 *
 *  Copyright (c) 2018 NRK. Licensed under the MIT license, as follows:
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

import XCTest
@testable import Cachyr

class DataCacheAccessTests: XCTestCase {
    var cache: DataCache!
    let expectationWaitTime: TimeInterval = 5

    override func setUp() {
        super.setUp()

        cache = DataCache()
    }

    override func tearDown() {
        super.tearDown()

        cache.removeAll()
    }

    func testContainsAccess() {
        let foo = "bar"
        let key = "foo"

        cache.removeAll()

        cache.setValue(foo, for: key)
        XCTAssertTrue(cache.contains(key: key, access: [.memory]))
        XCTAssertTrue(cache.contains(key: key, access: [.disk]))

        cache.removeAll()

        cache.setValue(foo, for: key, access: [.memory])
        XCTAssertTrue(cache.contains(key: key, access: [.memory]))
        XCTAssertFalse(cache.contains(key: key, access: [.disk]))

        cache.removeAll()

        cache.setValue(foo, for: key, access: [.disk])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertTrue(cache.contains(key: key, access: [.disk]))

        cache.removeAll()
    }

    func testValueAccess() {
        let foo = "bar"
        let key = "foo"

        cache.removeAll()

        cache.setValue(foo, for: key)
        let value: String? = cache.value(for: key)
        XCTAssertNotNil(value)

        cache.removeAll()

        cache.setValue(foo, for: key, access: [.memory])
        var memoryValue: String? = cache.value(for: key, access: [.memory])
        XCTAssertNotNil(memoryValue)
        var diskValue: String? = cache.value(for: key, access: [.disk])
        XCTAssertNil(diskValue)

        cache.removeAll()

        cache.setValue(foo, for: key, access: [.disk])
        memoryValue = cache.value(for: key, access: [.memory])
        XCTAssertNil(memoryValue)
        diskValue = cache.value(for: key, access: [.disk])
        XCTAssertNotNil(diskValue)

        cache.removeAll()
    }

    func testRemoveValueAccess() {
        let foo = "bar"
        let key = "foo"

        cache.removeAll()

        cache.setValue(foo, for: key)
        cache.removeValue(for: key, access: [.memory])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertTrue(cache.contains(key: key, access: [.disk]))

        cache.removeAll()

        cache.setValue(foo, for: key)
        cache.removeValue(for: key, access: [.disk])
        XCTAssertTrue(cache.contains(key: key, access: [.memory]))
        XCTAssertFalse(cache.contains(key: key, access: [.disk]))

        cache.removeAll()
    }

    func testRemoveAllAccess() {
        let foo = "bar"
        let bar = "wat"
        let fooKey = "foo"
        let barKey = "bar"

        cache.removeAll()

        cache.setValue(foo, for: fooKey)
        cache.setValue(bar, for: barKey)
        XCTAssertTrue(cache.contains(key: fooKey, access: [.memory]))
        XCTAssertTrue(cache.contains(key: barKey, access: [.memory]))
        XCTAssertTrue(cache.contains(key: fooKey, access: [.disk]))
        XCTAssertTrue(cache.contains(key: barKey, access: [.disk]))

        cache.removeAll(access: [.memory])
        XCTAssertFalse(cache.contains(key: fooKey, access: [.memory]))
        XCTAssertFalse(cache.contains(key: barKey, access: [.memory]))
        XCTAssertTrue(cache.contains(key: fooKey, access: [.disk]))
        XCTAssertTrue(cache.contains(key: barKey, access: [.disk]))

        cache.removeAll(access: [.disk])
        XCTAssertFalse(cache.contains(key: fooKey, access: [.memory]))
        XCTAssertFalse(cache.contains(key: barKey, access: [.memory]))
        XCTAssertFalse(cache.contains(key: fooKey, access: [.disk]))
        XCTAssertFalse(cache.contains(key: barKey, access: [.disk]))

        cache.removeAll()
    }

    func testRemoveExpiredAccess() {
        let foo = "bar"
        let key = "foo"

        cache.removeAll()

        cache.setValue(foo, for: key)
        cache.setExpirationDate(Date.distantPast, for: key)

        cache.removeExpired(access: [.memory])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertTrue(cache.contains(key: key, access: [.disk]))

        cache.removeExpired(access: [.disk])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertFalse(cache.contains(key: key, access: [.disk]))

        cache.removeAll()
    }

    func testRemoveOlderThanAccess() {
        let foo = "bar"
        let key = "foo"
        let maxExpire = Date(timeIntervalSinceNow: 10)
        let expires = Date(timeIntervalSinceNow: 1)

        cache.removeAll()

        cache.setValue(foo, for: key, expires: expires)

        cache.removeItems(olderThan: maxExpire, access: [.memory])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertTrue(cache.contains(key: key, access: [.disk]))

        cache.removeItems(olderThan: maxExpire, access: [.disk])
        XCTAssertFalse(cache.contains(key: key, access: [.memory]))
        XCTAssertFalse(cache.contains(key: key, access: [.disk]))

        cache.removeAll()
    }

    func testExpirationAccess() {
        let foo = "bar"
        let key = "foo"
        let expires = Date(timeIntervalSinceNow: 10)

        cache.removeAll()

        cache.setValue(foo, for: key)
        XCTAssertNil(cache.expirationDate(for: key, access: [.memory]))
        XCTAssertNil(cache.expirationDate(for: key, access: [.disk]))

        cache.setExpirationDate(expires, for: key, access: [.memory])
        XCTAssertNotNil(cache.expirationDate(for: key, access: [.memory]))
        XCTAssertNil(cache.expirationDate(for: key, access: [.disk]))

        cache.setExpirationDate(nil, for: key, access: [.memory])
        cache.setExpirationDate(expires, for: key, access: [.disk])
        XCTAssertNil(cache.expirationDate(for: key, access: [.memory]))
        XCTAssertNotNil(cache.expirationDate(for: key, access: [.disk]))

        cache.removeAll()
    }

}

#if os(Linux)
    extension DataCacheTests {
        static var allTests : [(String, (DataCacheTests) -> () throws -> Void)] {
            return [
                ("testContainsAccess", testContainsAccess),
                ("testValueAccess", testValueAccess),
                ("testRemoveValueAccess", testRemoveValueAccess),
                ("testRemoveAllAccess", testRemoveAllAccess),
                ("testRemoveExpiredAccess", testRemoveExpiredAccess),
                ("testRemoveOlderThanAccess", testRemoveOlderThanAccess),
                ("testExpirationAccess", testExpirationAccess)
            ]
        }
    }
#endif
