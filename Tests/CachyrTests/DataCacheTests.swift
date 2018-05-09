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

import XCTest
@testable import Cachyr

struct Book {
    let title: String
}

extension Book: DataConvertable {
    static func data(from value: Book) -> Data? {
        let json: [String: Any] = ["title": value.title]
        let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        return data
    }

    static func value(from data: Data) -> Book? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            return nil
        }
        if let title = jsonDict["title"] as? String {
            return Book(title: title)
        }
        return nil
    }
}

class DataCacheTests: XCTestCase {
    var cache: DataCache<String>!
    let expectationWaitTime: TimeInterval = 5

    override func setUp() {
        super.setUp()

        cache = DataCache<String>()
    }

    override func tearDown() {
        super.tearDown()

        cache.removeAll()
    }

    func testAsyncStringValue() {
        let valueExpectation = expectation(description: "String value in cache")
        let foo = "bar"
        cache.setValue(foo, forKey: "foo") {
            self.cache.value(forKey: "foo") {
                (value) in
                XCTAssertNotNil(value)
                XCTAssertEqual(foo, value!)
                valueExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncStringValue() {
        let foo = "bar"
        cache.setValue(foo, forKey: "foo")
        let value = cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value!)
    }

    func testAsyncContains() {
        let expect = expectation(description: "Cache contains key")
        let key = "foo"
        cache.contains(key: key) { (found) in
            XCTAssertFalse(found)
            self.cache.setValue(key, forKey: key)
            self.cache.contains(key: key, completion: { (found) in
                XCTAssertTrue(found)
                expect.fulfill()
            })
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncContains() {
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testAsyncRemove() {
        let expect = expectation(description: "Remove value in cache")
        let foo = "foo"
        cache.setValue(foo, forKey: foo) {
            self.cache.value(forKey: foo) { (value) in
                XCTAssertNotNil(value)
                self.cache.removeValue(forKey: foo) {
                    self.cache.value(forKey: foo) { (value) in
                        XCTAssertNil(value)
                        expect.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemove() {
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        var value = cache.value(forKey: foo)
        XCTAssertNotNil(value)
        cache.removeValue(forKey: foo)
        value = cache.value(forKey: foo)
        XCTAssertNil(value)
    }

    func testAsyncRemoveAll() {
        let valueExpectation = expectation(description: "Remove all in cache")
        let foo = "foo"
        let bar = "bar"

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar) {
            self.cache.removeAll() {
                self.cache.value(forKey: foo) { (value) in
                    XCTAssertNil(value)
                    self.cache.value(forKey: bar) { (value) in
                        XCTAssertNil(value)
                        valueExpectation.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemoveAll() {
        let foo = "foo"
        let bar = "bar"

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar)
        self.cache.removeAll()
        var value = cache.value(forKey: foo)
        XCTAssertNil(value)
        value = cache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testAsyncRemoveExpired() {
        let valueExpectation = expectation(description: "Remove expired in cache")
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar, expires: barExpireDate)
        cache.removeExpired() {
            self.cache.value(forKey: foo) { (value) in
                XCTAssertNotNil(value)
                self.cache.value(forKey: bar) { (value) in
                    XCTAssertNil(value)
                    valueExpectation.fulfill()
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemoveExpired() {
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar, expires: barExpireDate)
        cache.removeExpired()
        var value = cache.value(forKey: foo)
        XCTAssertNotNil(value)
        value = cache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testAsyncSetGetExpiration() {
        let expect = expectation(description: "Async get/set expiration")
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())

        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        cache.expirationDate(forKey: foo) { (noExpire) in
            XCTAssertNil(noExpire)
            self.cache.setExpirationDate(expires, forKey: foo, completion: {
                self.cache.expirationDate(forKey: foo, completion: { (expire) in
                    XCTAssertNotNil(expire)
                    XCTAssertEqual(expires, expire)
                    expect.fulfill()
                })
            })
        }

        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncSetGetExpiration() {
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.expirationDate(forKey: foo)
        XCTAssertNil(noExpire)
        cache.setExpirationDate(expires, forKey: foo)
        let expire = cache.expirationDate(forKey: foo)
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire)
    }

    func testAsyncRemoveItemsOlderThan() {
        let expect = expectation(description: "Remove items older than")
        let foo = "foo"
        cache.setValue(foo, forKey: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30)) {
            self.cache.value(forKey: foo) { (value) in
                XCTAssertNotNil(value)

                self.cache.removeItems(olderThan: Date()) {
                    self.cache.value(forKey: foo) { (value) in
                        XCTAssertNil(value)
                        expect.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: expectationWaitTime)
    }
    
    func testSyncRemoveItemsOlderThan() {
        let foo = "foo"
        cache.setValue(foo, forKey: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30))
        var value = cache.value(forKey: foo)
        XCTAssertNotNil(value)

        cache.removeItems(olderThan: Date())
        value = cache.value(forKey: foo)
        XCTAssertNil(value)
    }

    func testCompletionBackgroundQueue() {
        let expect = expectation(description: "Background queue completion")
        let currentThread = Thread.current
        let cache = DataCache<String>(name: "backgroundTest")
        cache.setValue("asdf", forKey: "foo")
        cache.value(forKey: "foo") { (_) in
            XCTAssertNotEqual(currentThread, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
    }

    func testCompletionMainQueue() {
        let expect = expectation(description: "Main queue completion")
        let cache = DataCache<String>(name: "mainQueueTest", completionQueue: .main)
        cache.setValue("asdf", forKey: "foo")
        cache.value(forKey: "foo") { (_) in
            XCTAssertEqual(Thread.main, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
    }

    func testModelTransform() {
        let cache = DataCache<Book>()
        let weaveworld = Book(title: "Weaveworld")
        let key = "book"
        cache.setValue(weaveworld, forKey: key, access: [.disk])

        let book = cache.value(forKey: key)
        XCTAssertNotNil(book)
        XCTAssertEqual(weaveworld.title, book!.title)
    }

    func testDiskAndMemoryExpiration() {
        let key = "foo"
        let value = "bar"
        let expires = Date.distantFuture

        cache.diskCache.setValue(value, forKey: key, expires: expires)
        let diskExpires = cache.diskCache.expirationDate(forKey: key)!
        XCTAssertEqual(diskExpires, expires)

        // Populate memory cache by requesting value in data cache
        let cacheValue = cache.value(forKey: key)
        XCTAssertNotNil(cacheValue)
        let memoryExpires = cache.memoryCache.expirationDate(forKey: key)
        XCTAssertEqual(memoryExpires, expires)
    }
}

#if os(Linux)
    extension DataCacheTests {
        static var allTests : [(String, (DataCacheTests) -> () throws -> Void)] {
            return [
                ("testAsyncDataValue", testAsyncDataValue),
                ("testSyncDataValue", testSyncDataValue),
                ("testAsyncStringValue", testAsyncStringValue),
                ("testSyncStringValue", testSyncStringValue),
                ("testAsyncRemove", testAsyncRemove),
                ("testSyncRemove", testSyncRemove),
                ("testAsyncRemoveAll", testAsyncRemoveAll),
                ("testSyncRemoveAll", testSyncRemoveAll),
                ("testAsyncRemoveExpired", testAsyncRemoveExpired),
                ("testSyncRemoveExpired", testSyncRemoveExpired),
                ("testAsyncRemoveItemsOlderThan", testAsyncRemoveItemsOlderThan),
                ("testSyncRemoveItemsOlderThan", testSyncRemoveItemsOlderThan),
                ("testCompletionBackgroundQueue", testCompletionBackgroundQueue),
                ("testCompletionMainQueue", testCompletionMainQueue),
            ]
        }
    }
#endif
