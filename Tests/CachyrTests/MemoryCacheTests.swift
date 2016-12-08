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

class MemoryCacheTests: XCTestCase {
    var cache: MemoryCache!

    override func setUp() {
        super.setUp()

        cache = MemoryCache()
    }

    override func tearDown() {
        super.tearDown()

        cache = nil
    }

    func testIntValues() {
        cache.setValue(42, for: "Int")
        let intValue: Int? = cache.value(for: "Int")
        XCTAssertNotNil(intValue)
        XCTAssertEqual(42, intValue!)
    }

    func testDoubleValues() {
        cache.setValue(42.0, for: "Double")
        let doubleValue: Double? = cache.value(for: "Double")
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(42.0, doubleValue!)
    }

    func testStringValues() {
        cache.setValue("Test", for: "String")
        let stringValue: String? = cache.value(for: "String")
        XCTAssertNotNil(stringValue)
        XCTAssertEqual("Test", stringValue!)
    }

    func testStructValues() {
        struct Foo {
            let bar = "Bar"
        }

        cache.setValue(Foo(), for: "Foo")
        let foo: Foo? = cache.value(for: "Foo")
        XCTAssertNotNil(foo)
        XCTAssertEqual("Bar", foo!.bar)
    }

    func testClassValues() {
        class Foo {
            let bar = "Bar"
        }

        cache.setValue(Foo(), for: "Foo")
        let foo: Foo? = cache.value(for: "Foo")
        XCTAssertNotNil(foo)
        XCTAssertEqual("Bar", foo!.bar)
    }

    func testRemove() {
        let key = "foo"
        cache.setValue(key, for: key)
        var value: String? = cache.value(for: key)
        XCTAssertNotNil(value)
        cache.removeValue(for: key)
        value = cache.value(for: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        let values = [1, 2, 3]
        for i in values {
            cache.setValue(i, for: "\(i)")
        }
        for i in values {
            let value: Int? = cache.value(for: "\(i)")
            XCTAssertNotNil(value)
            XCTAssertEqual(value!, i)
        }
        cache.removeAll()
        for i in values {
            let value: Int? = cache.value(for: "\(i)")
            XCTAssertNil(value)
        }
    }

    func testExpiration() {
        let foo = "foo"

        let hasNotExpiredDate = Date(timeIntervalSinceNow: 30)
        cache.setValue(foo, for: foo, expires: hasNotExpiredDate)
        let notExpiredValue: String? = cache.value(for: foo)
        XCTAssertNotNil(notExpiredValue)

        let hasExpiredDate = Date(timeIntervalSinceNow: -30)
        cache.setValue(foo, for: foo, expires: hasExpiredDate)
        let expiredValue: String? = cache.value(for: foo)
        XCTAssertNil(expiredValue)
    }

    func testRemoveExpired() {
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, for: foo)
        cache.setValue(bar, for: bar, expires: barExpireDate)
        cache.removeExpired()

        let fooValue: String? = cache.value(for: foo)
        XCTAssertNotNil(fooValue)
        let barValue: String? = cache.value(for: bar)
        XCTAssertNil(barValue)
    }

    func testExpirationInterval() {
        let foo = "foo"
        cache.setValue(foo, for: foo, expires: Date())
        cache.checkExpiredInterval = 0
        let fooValue: String? = cache.value(for: foo)
        XCTAssertNil(fooValue)
    }

    func testRemoveItemsOlderThan() {
        let foo = "foo"
        cache.setValue(foo, for: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30))
        XCTAssertNotNil(cache.value(for: foo))

        cache.removeItems(olderThan: Date())
        XCTAssertNil(cache.value(for: foo))
    }

    func testInteger() {
        let int = Int(Int.min)
        cache.setValue(int, for: "Int")
        let intValue: Int? = cache.value(for: "Int")
        XCTAssertNotNil(intValue)
        XCTAssertEqual(intValue!, int)

        let int8 = Int8(Int8.min)
        cache.setValue(int8, for: "Int8")
        let int8Value: Int8? = cache.value(for: "Int8")
        XCTAssertNotNil(int8Value)
        XCTAssertEqual(int8Value!, int8)

        let int16 = Int16(Int16.min)
        cache.setValue(int16, for: "Int16")
        let int16Value: Int16? = cache.value(for: "Int16")
        XCTAssertNotNil(int16Value)
        XCTAssertEqual(int16Value!, int16)

        let int32 = Int32(Int32.min)
        cache.setValue(int32, for: "Int32")
        let int32Value: Int32? = cache.value(for: "Int32")
        XCTAssertNotNil(int32Value)
        XCTAssertEqual(int32Value!, int32)

        let int64 = Int64(Int64.min)
        cache.setValue(int64, for: "Int64")
        let int64Value: Int64? = cache.value(for: "Int64")
        XCTAssertNotNil(int64Value)
        XCTAssertEqual(int64Value!, int64)

        let uint = UInt(UInt.max)
        cache.setValue(uint, for: "UInt")
        let uintValue: UInt? = cache.value(for: "UInt")
        XCTAssertNotNil(uintValue)
        XCTAssertEqual(uintValue!, uint)

        let uint8 = UInt8(UInt8.max)
        cache.setValue(uint8, for: "UInt8")
        let uint8Value: UInt8? = cache.value(for: "UInt8")
        XCTAssertNotNil(uint8Value)
        XCTAssertEqual(uint8Value!, uint8)

        let uint16 = UInt16(UInt16.max)
        cache.setValue(uint16, for: "UInt16")
        let uint16Value: UInt16? = cache.value(for: "UInt16")
        XCTAssertNotNil(uint16Value)
        XCTAssertEqual(uint16Value!, uint16)

        let uint32 = UInt32(UInt32.max)
        cache.setValue(uint32, for: "UInt32")
        let uint32Value: UInt32? = cache.value(for: "UInt32")
        XCTAssertNotNil(uint32Value)
        XCTAssertEqual(uint32Value!, uint32)

        let uint64 = UInt64(UInt64.max)
        cache.setValue(uint64, for: "UInt64")
        let uint64Value: UInt64? = cache.value(for: "UInt64")
        XCTAssertNotNil(uint64Value)
        XCTAssertEqual(uint64Value!, uint64)
    }

    func testFloatingPoint() {
        let float = Float(Float.pi)
        cache.setValue(float, for: "Float")
        let floatValue: Float? = cache.value(for: "Float")
        XCTAssertNotNil(floatValue)
        XCTAssertEqual(floatValue!, float)

        let negFloat = Float(-Float.pi)
        cache.setValue(negFloat, for: "negFloat")
        let negFloatValue: Float? = cache.value(for: "negFloat")
        XCTAssertNotNil(negFloatValue)
        XCTAssertEqual(negFloatValue!, negFloat)

        let infFloat = Float.infinity
        cache.setValue(infFloat, for: "infFloat")
        let infFloatValue: Float? = cache.value(for: "infFloat")
        XCTAssertNotNil(infFloatValue)
        XCTAssertEqual(infFloatValue!, infFloat)

        let nanFloat = Float.nan
        cache.setValue(nanFloat, for: "nanFloat")
        let nanFloatValue: Float? = cache.value(for: "nanFloat")
        XCTAssertNotNil(nanFloatValue)
        XCTAssertEqual(nanFloatValue!.isNaN, nanFloat.isNaN)

        let double = Double(Double.pi)
        cache.setValue(double, for: "Double")
        let doubleValue: Double? = cache.value(for: "Double")
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, double)

        let negDouble = Double(-Double.pi)
        cache.setValue(negDouble, for: "negDouble")
        let negDoubleValue: Double? = cache.value(for: "negDouble")
        XCTAssertNotNil(negDoubleValue)
        XCTAssertEqual(negDoubleValue!, negDouble)

        let infDouble = Double.infinity
        cache.setValue(infDouble, for: "infDouble")
        let infDoubleValue: Double? = cache.value(for: "infDouble")
        XCTAssertNotNil(infDoubleValue)
        XCTAssertEqual(infDoubleValue!, infDouble)

        let nanDouble = Double.nan
        cache.setValue(nanDouble, for: "nanDouble")
        let nanDoubleValue: Double? = cache.value(for: "nanDouble")
        XCTAssertNotNil(nanDoubleValue)
        XCTAssertEqual(nanDoubleValue!.isNaN, nanDouble.isNaN)
    }
}

#if os(Linux)
    extension MemoryCacheTests {
        static var allTests : [(String, (MemoryCacheTests) -> () throws -> Void)] {
            return [
                ("testIntValues", testIntValues),
                ("testDoubleValues", testDoubleValues),
                ("testStringValues", testStringValues),
                ("testStructValues", testStructValues),
                ("testClassValues", testClassValues),
                ("testRemove", testRemove),
                ("testRemoveAll", testRemoveAll),
                ("testExpiration", testExpiration),
                ("testRemoveExpired", testRemoveExpired),
                ("testExpirationInterval", testExpirationInterval),
                ("testRemoveItemsOlderThan", testRemoveItemsOlderThan),
                ("testInteger", testInteger),
                ("testFloatingPoint", testFloatingPoint),
            ]
        }
    }
#endif
