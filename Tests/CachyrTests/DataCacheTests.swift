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

    func testAsyncDataValue() {
        let valueExpectation = expectation(description: "Data value in cache")
        let foo = "bar".data(using: .utf8)!
        cache.setValue(foo, for: "foo") {
            self.cache.value(for: "foo") {
                (value: Data?) in
                XCTAssertNotNil(value)
                XCTAssertEqual(foo, value!)
                valueExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncDataValue() {
        let foo = "bar".data(using: .utf8)!
        cache.setValue(foo, for: "foo")
        let value: Data? = cache.value(for: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value!)
    }

    func testAsyncStringValue() {
        let valueExpectation = expectation(description: "String value in cache")
        let foo = "bar"
        cache.setValue(foo, for: "foo") {
            self.cache.value(for: "foo") {
                (value: String?) in
                XCTAssertNotNil(value)
                XCTAssertEqual(foo, value!)
                valueExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncStringValue() {
        let foo = "bar"
        cache.setValue(foo, for: "foo") {
        }
        let value: String? = cache.value(for: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value!)
    }

    func testAsyncRemove() {
        let expect = expectation(description: "Remove value in cache")
        let foo = "foo"
        cache.setValue(foo, for: foo) {
            self.cache.value(for: foo) { (value: String?) in
                XCTAssertNotNil(value)
                self.cache.removeValue(for: foo) {
                    self.cache.value(for: foo) { (value: String?) in
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
        cache.setValue(foo, for: foo)
        var value: String? = cache.value(for: foo)
        XCTAssertNotNil(value)
        cache.removeValue(for: foo)
        value = cache.value(for: foo)
        XCTAssertNil(value)
    }

    func testAsyncRemoveAll() {
        let valueExpectation = expectation(description: "Remove all in cache")
        let foo = "foo"
        let bar = "bar"

        cache.setValue(foo, for: foo)
        cache.setValue(bar, for: bar) {
            self.cache.removeAll() {
                self.cache.value(for: foo) { (value: String?) in
                    XCTAssertNil(value)
                    self.cache.value(for: bar) { (value: String?) in
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

        cache.setValue(foo, for: foo)
        cache.setValue(bar, for: bar)
        self.cache.removeAll()
        var value: String? = cache.value(for: foo)
        XCTAssertNil(value)
        value = cache.value(for: bar)
        XCTAssertNil(value)
    }

    func testAsyncRemoveExpired() {
        let valueExpectation = expectation(description: "Remove expired in cache")
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, for: foo)
        cache.setValue(bar, for: bar, expires: barExpireDate)
        cache.removeExpired() {
            self.cache.value(for: foo) { (value: String?) in
                XCTAssertNotNil(value)
                self.cache.value(for: bar) { (value: String?) in
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

        cache.setValue(foo, for: foo)
        cache.setValue(bar, for: bar, expires: barExpireDate)
        cache.removeExpired()
        var value: String? = cache.value(for: foo)
        XCTAssertNotNil(value)
        value = cache.value(for: bar)
        XCTAssertNil(value)
    }

    func testAsyncRemoveItemsOlderThan() {
        let expect = expectation(description: "Remove items older than")
        let foo = "foo"
        cache.setValue(foo, for: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30)) {
            self.cache.value(for: foo) { (value: String?) in
                XCTAssertNotNil(value)

                self.cache.removeItems(olderThan: Date()) {
                    self.cache.value(for: foo) { (value: String?) in
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
        cache.setValue(foo, for: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30))
        var value: String? = cache.value(for: foo)
        XCTAssertNotNil(value)

        cache.removeItems(olderThan: Date())
        value = cache.value(for: foo)
        XCTAssertNil(value)
    }

    func testCompletionBackgroundQueue() {
        let expect = expectation(description: "Background queue completion")
        let currentThread = Thread.current
        let cache = DataCache(name: "backgroundTest")
        cache.setValue("asdf", for: "foo")
        cache.value(for: "foo") { (value: String?) in
            XCTAssertNotEqual(currentThread, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
    }

    func testCompletionMainQueue() {
        let expect = expectation(description: "Main queue completion")
        let cache = DataCache(name: "mainQueueTest", completionQueue: DispatchQueue.main)
        cache.setValue("asdf", for: "foo")
        cache.value(for: "foo") { (value: String?) in
            XCTAssertEqual(Thread.main, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
    }

    func testModelTransform() {
        let weaveworld = Book(title: "Weaveworld")
        let key = "book"
        cache.setValue(weaveworld, for: key)

        let data: Data? = cache.value(for: key)
        XCTAssertNotNil(data)

        let text: String? = cache.value(for: key)
        XCTAssertNotNil(text)

        let book: Book? = cache.value(for: key)
        XCTAssertNotNil(book)
        XCTAssertEqual(weaveworld.title, book!.title)
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
