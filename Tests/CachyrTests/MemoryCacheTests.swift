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
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIntValues() {
        let cache = MemoryCache<Int>()
        cache.setValue(42, forKey: "Int")
        let intValue = cache.value(forKey: "Int")
        XCTAssertNotNil(intValue)
        XCTAssertEqual(42, intValue!)
    }

    func testDoubleValues() {
        let cache = MemoryCache<Double>()
        cache.setValue(42.0, forKey: "Double")
        let doubleValue = cache.value(forKey: "Double")
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(42.0, doubleValue!)
    }

    func testStringValues() {
        let cache = MemoryCache<String>()
        cache.setValue("Test", forKey: "String")
        let stringValue = cache.value(forKey: "String")
        XCTAssertNotNil(stringValue)
        XCTAssertEqual("Test", stringValue!)
    }

    func testStructValues() {
        struct Foo {
            let bar = "Bar"
        }

        let cache = MemoryCache<Foo>()
        cache.setValue(Foo(), forKey: "Foo")
        let foo = cache.value(forKey: "Foo")
        XCTAssertNotNil(foo)
        XCTAssertEqual("Bar", foo!.bar)
    }

    func testClassValues() {
        class Foo {
            let bar = "Bar"
        }

        let cache = MemoryCache<Foo>()
        cache.setValue(Foo(), forKey: "Foo")
        let foo = cache.value(forKey: "Foo")
        XCTAssertNotNil(foo)
        XCTAssertEqual("Bar", foo!.bar)
    }

    func testContains() {
        let cache = MemoryCache<String>()
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() {
        let cache = MemoryCache<String>()
        let key = "foo"
        cache.setValue(key, forKey: key)
        var value = cache.value(forKey: key)
        XCTAssertNotNil(value)
        cache.removeValue(forKey: key)
        value = cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        let cache = MemoryCache<Int>()
        let values = [1, 2, 3]
        for i in values {
            cache.setValue(i, forKey: "\(i)")
        }
        for i in values {
            let value = cache.value(forKey: "\(i)")
            XCTAssertNotNil(value)
            XCTAssertEqual(value!, i)
        }
        cache.removeAll()
        for i in values {
            let value = cache.value(forKey: "\(i)")
            XCTAssertNil(value)
        }
    }

    func testExpiration() {
        let cache = MemoryCache<String>()
        let foo = "foo"

        let hasNotExpiredDate = Date(timeIntervalSinceNow: 30)
        cache.setValue(foo, forKey: foo, expires: hasNotExpiredDate)
        let notExpiredValue = cache.value(forKey: foo)
        XCTAssertNotNil(notExpiredValue)

        let hasExpiredDate = Date(timeIntervalSinceNow: -30)
        cache.setValue(foo, forKey: foo, expires: hasExpiredDate)
        let expiredValue = cache.value(forKey: foo)
        XCTAssertNil(expiredValue)
    }

    func testRemoveExpired() {
        let cache = MemoryCache<String>()
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar, expires: barExpireDate)
        cache.removeExpired()

        let fooValue = cache.value(forKey: foo)
        XCTAssertNotNil(fooValue)
        let barValue = cache.value(forKey: bar)
        XCTAssertNil(barValue)
    }

    func testExpirationInterval() {
        let cache = MemoryCache<String>()
        let foo = "foo"
        cache.setValue(foo, forKey: foo, expires: Date())
        cache.checkExpiredInterval = 0
        let fooValue = cache.value(forKey: foo)
        XCTAssertNil(fooValue)
    }

    func testSetGetExpiration() {
        let cache = MemoryCache<String>()
        let expires = Date().addingTimeInterval(10)
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.expirationDate(forKey: foo)
        XCTAssertNil(noExpire)
        cache.setExpirationDate(expires, forKey: foo)
        let expire = cache.expirationDate(forKey: foo)
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire)
    }

    func testRemoveExpiration() {
        let cache = MemoryCache<String>()
        let expiration = Date().addingTimeInterval(10)
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.expirationDate(forKey: foo)
        XCTAssertNil(noExpire)
        cache.setExpirationDate(expiration, forKey: foo)
        let expire = cache.expirationDate(forKey: foo)
        XCTAssertNotNil(expire)
        cache.setExpirationDate(nil, forKey: foo)
        let expirationGone = cache.expirationDate(forKey: foo)
        XCTAssertNil(expirationGone)
    }

    func testRemoveItemsOlderThan() {
        let cache = MemoryCache<String>()
        let foo = "foo"
        cache.setValue(foo, forKey: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30))
        XCTAssertNotNil(cache.value(forKey: foo))

        cache.removeItems(olderThan: Date())
        XCTAssertNil(cache.value(forKey: foo))
    }

    func testInteger() {
        let cacheInt = MemoryCache<Int>()
        let int = Int(Int.min)
        cacheInt.setValue(int, forKey: "Int")
        let intValue = cacheInt.value(forKey: "Int")
        XCTAssertNotNil(intValue)
        XCTAssertEqual(intValue!, int)

        let cacheInt8 = MemoryCache<Int8>()
        let int8 = Int8(Int8.min)
        cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = cacheInt8.value(forKey: "Int8")
        XCTAssertNotNil(int8Value)
        XCTAssertEqual(int8Value!, int8)

        let cacheInt16 = MemoryCache<Int16>()
        let int16 = Int16(Int16.min)
        cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = cacheInt16.value(forKey: "Int16")
        XCTAssertNotNil(int16Value)
        XCTAssertEqual(int16Value!, int16)

        let cacheInt32 = MemoryCache<Int32>()
        let int32 = Int32(Int32.min)
        cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = cacheInt32.value(forKey: "Int32")
        XCTAssertNotNil(int32Value)
        XCTAssertEqual(int32Value!, int32)

        let cacheInt64 = MemoryCache<Int64>()
        let int64 = Int64(Int64.min)
        cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = cacheInt64.value(forKey: "Int64")
        XCTAssertNotNil(int64Value)
        XCTAssertEqual(int64Value!, int64)

        let cacheUInt = MemoryCache<UInt>()
        let uint = UInt(UInt.max)
        cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = cacheUInt.value(forKey: "UInt")
        XCTAssertNotNil(uintValue)
        XCTAssertEqual(uintValue!, uint)

        let cacheUInt8 = MemoryCache<UInt8>()
        let uint8 = UInt8(UInt8.max)
        cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = cacheUInt8.value(forKey: "UInt8")
        XCTAssertNotNil(uint8Value)
        XCTAssertEqual(uint8Value!, uint8)

        let cacheUInt16 = MemoryCache<UInt16>()
        let uint16 = UInt16(UInt16.max)
        cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = cacheUInt16.value(forKey: "UInt16")
        XCTAssertNotNil(uint16Value)
        XCTAssertEqual(uint16Value!, uint16)

        let cacheUInt32 = MemoryCache<UInt32>()
        let uint32 = UInt32(UInt32.max)
        cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = cacheUInt32.value(forKey: "UInt32")
        XCTAssertNotNil(uint32Value)
        XCTAssertEqual(uint32Value!, uint32)

        let cacheUInt64 = MemoryCache<UInt64>()
        let uint64 = UInt64(UInt64.max)
        cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = cacheUInt64.value(forKey: "UInt64")
        XCTAssertNotNil(uint64Value)
        XCTAssertEqual(uint64Value!, uint64)
    }

    func testFloatingPoint() {
        let cacheFloat = MemoryCache<Float>()

        let float = Float(Float.pi)
        cacheFloat.setValue(float, forKey: "Float")
        let floatValue = cacheFloat.value(forKey: "Float")
        XCTAssertNotNil(floatValue)
        XCTAssertEqual(floatValue!, float)

        let negFloat = Float(-Float.pi)
        cacheFloat.setValue(negFloat, forKey: "negFloat")
        let negFloatValue = cacheFloat.value(forKey: "negFloat")
        XCTAssertNotNil(negFloatValue)
        XCTAssertEqual(negFloatValue!, negFloat)

        let infFloat = Float.infinity
        cacheFloat.setValue(infFloat, forKey: "infFloat")
        let infFloatValue = cacheFloat.value(forKey: "infFloat")
        XCTAssertNotNil(infFloatValue)
        XCTAssertEqual(infFloatValue!, infFloat)

        let nanFloat = Float.nan
        cacheFloat.setValue(nanFloat, forKey: "nanFloat")
        let nanFloatValue = cacheFloat.value(forKey: "nanFloat")
        XCTAssertNotNil(nanFloatValue)
        XCTAssertEqual(nanFloatValue!.isNaN, nanFloat.isNaN)

        let cacheDouble = MemoryCache<Double>()

        let double = Double(Double.pi)
        cacheDouble.setValue(double, forKey: "Double")
        let doubleValue = cacheDouble.value(forKey: "Double")
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, double)

        let negDouble = Double(-Double.pi)
        cacheDouble.setValue(negDouble, forKey: "negDouble")
        let negDoubleValue = cacheDouble.value(forKey: "negDouble")
        XCTAssertNotNil(negDoubleValue)
        XCTAssertEqual(negDoubleValue!, negDouble)

        let infDouble = Double.infinity
        cacheDouble.setValue(infDouble, forKey: "infDouble")
        let infDoubleValue = cacheDouble.value(forKey: "infDouble")
        XCTAssertNotNil(infDoubleValue)
        XCTAssertEqual(infDoubleValue!, infDouble)

        let nanDouble = Double.nan
        cacheDouble.setValue(nanDouble, forKey: "nanDouble")
        let nanDoubleValue = cacheDouble.value(forKey: "nanDouble")
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
