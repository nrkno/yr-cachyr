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

class StringDataSource: CacheDataSource {
    var wait = 0.0

    func data(for key: String, clientData: DataSourceClientData? = nil, completion: @escaping (Data?, Date?) -> Void) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + wait) {
            let data = key.data(using: .utf8)
            completion(data, nil)
        }
    }
}

class CacheDataSourceTests: XCTestCase {
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

    func testStringDataSource() {
        cache.dataSource = StringDataSource()
        let expect = expectation(description: "String data source")
        let key = "foo"
        cache.value(for: key) { (value: String?) in
            XCTAssertNotNil(value)
            XCTAssertEqual(value!, key)

            self.cache.dataSource = nil
            self.cache.value(for: key) { (value: String?) in
                XCTAssertNotNil(value)
                XCTAssertEqual(value!, key)
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testDataSourceDeferredCompletion() {
        let dataSource = StringDataSource()
        dataSource.wait = 0.1
        cache.dataSource = dataSource

        let expect = expectation(description: "Deferred completion")
        let keys = ["1", "1", "1"]
        var completionCount = 0
        for key in keys {
            cache.value(for: key) { (value: String?) in
                XCTAssertNotNil(value)
                XCTAssertEqual(value!, key)
                DispatchQueue.main.async {
                    completionCount += 1
                    if completionCount == keys.count {
                        expect.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }
}

#if os(Linux)
    extension CacheDataSourceTests {
        static var allTests : [(String, (CacheDataSourceTests) -> () throws -> Void)] {
            return [
                ("testStringDataSource", testStringDataSource),
                ("testDataSourceDeferredCompletion", testDataSourceDeferredCompletion),
            ]
        }
    }
#endif
