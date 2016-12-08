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

    func testDataValue() {
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

    func testStringValue() {
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

    func testRemove() {
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

    func testRemoveAll() {
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

    func testRemoveExpired() {
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

    func testRemoveItemsOlderThan() {
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
}

#if os(Linux)
    extension DataCacheTests {
        static var allTests : [(String, (DataCacheTests) -> () throws -> Void)] {
            return [
                ("testDataValue", testDataValue),
                ("testStringValue", testStringValue),
                ("testRemove", testRemove),
                ("testRemoveAll", testRemoveAll),
                ("testRemoveExpired", testRemoveExpired),
                ("testRemoveItemsOlderThan", testRemoveItemsOlderThan),
                ("testCompletionBackgroundQueue", testCompletionBackgroundQueue),
                ("testCompletionMainQueue", testCompletionMainQueue),
            ]
        }
    }
#endif
