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

class DiskCacheTests: XCTestCase {
    var cache: DiskCache<String>!

    override func setUp() {
        super.setUp()

        cache = DiskCache<String>(name: "no.nrk.yr.cache-test")
    }

    override func tearDown() {
        super.tearDown()

        cache.removeAll()
    }

    func testDataValue() {
        let cache = DiskCache<Data>()!
        defer { cache.removeAll() }

        let foo = "bar".data(using: .utf8)!
        cache.setValue(foo, forKey: "foo")
        let value = cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testStringValue() {
        let foo = "bar"
        cache.setValue(foo, forKey: "foo")
        let value = cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testContains() {
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() {
        let key = "foo"
        cache.setValue(key, forKey: key)
        var value = cache.value(forKey: key)
        XCTAssertNotNil(value)
        cache.removeValue(forKey: key)
        value = cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        cache.setValue("foo", forKey: "foo")
        cache.setValue("bar", forKey: "bar")
        cache.removeAll()
        let foo = cache.value(forKey: "foo")
        XCTAssertNil(foo)
        let bar = cache.value(forKey: "bar")
        XCTAssertNil(bar)
    }

    func testFileCreation() {
        let key = "/foo:b/ar\\"
        cache.setValue(key, forKey: key)
        let fileURL = cache.fileURL(forKey: key)
        XCTAssertNotNil(fileURL)
        let exists = FileManager.default.fileExists(atPath: fileURL!.path)
        XCTAssertTrue(exists)
    }

    func testExpiration() {
        let foo = "foo"

        cache.setValue(foo, forKey: foo)
        let expirationInFutureValue = cache.value(forKey: foo)
        XCTAssertNotNil(expirationInFutureValue)

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

    func testSetGetExpiration() {
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

    func testRemoveExpiration() {
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
        let foo = "foo"
        cache.setValue(foo, forKey: foo)

        cache.removeItems(olderThan: Date(timeIntervalSinceNow: -30))
        XCTAssertNotNil(cache.value(forKey: foo) as String?)

        cache.removeItems(olderThan: Date())
        XCTAssertNil(cache.value(forKey: foo) as String?)
    }

    func testStorageSize() {
        let data = "123456789"
        let dataSize = data.utf8.count
        cache.setValue(data, forKey: "data")
        let size = cache.storageSize
        XCTAssertEqual(dataSize, size)
    }

    func testInteger() {
        let cacheInt = DiskCache<Int>()!
        defer { cacheInt.removeAll() }
        let int = Int(Int.min)
        cacheInt.setValue(int, forKey: "Int")
        let intValue = cacheInt.value(forKey: "Int")
        XCTAssertNotNil(intValue)
        XCTAssertEqual(intValue!, int)

        let cacheInt8 = DiskCache<Int8>()!
        defer { cacheInt8.removeAll() }
        let int8 = Int8(Int8.min)
        cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = cacheInt8.value(forKey: "Int8")
        XCTAssertNotNil(int8Value)
        XCTAssertEqual(int8Value!, int8)

        let cacheInt16 = DiskCache<Int16>()!
        defer { cacheInt16.removeAll() }
        let int16 = Int16(Int16.min)
        cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = cacheInt16.value(forKey: "Int16")
        XCTAssertNotNil(int16Value)
        XCTAssertEqual(int16Value!, int16)

        let cacheInt32 = DiskCache<Int32>()!
        defer { cacheInt32.removeAll() }
        let int32 = Int32(Int32.min)
        cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = cacheInt32.value(forKey: "Int32")
        XCTAssertNotNil(int32Value)
        XCTAssertEqual(int32Value!, int32)

        let cacheInt64 = DiskCache<Int64>()!
        defer { cacheInt64.removeAll() }
        let int64 = Int64(Int64.min)
        cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = cacheInt64.value(forKey: "Int64")
        XCTAssertNotNil(int64Value)
        XCTAssertEqual(int64Value!, int64)

        let cacheUInt = DiskCache<UInt>()!
        defer { cacheUInt.removeAll() }
        let uint = UInt(UInt.max)
        cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = cacheUInt.value(forKey: "UInt")
        XCTAssertNotNil(uintValue)
        XCTAssertEqual(uintValue!, uint)

        let cacheUInt8 = DiskCache<UInt8>()!
        defer { cacheUInt8.removeAll() }
        let uint8 = UInt8(UInt8.max)
        cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = cacheUInt8.value(forKey: "UInt8")
        XCTAssertNotNil(uint8Value)
        XCTAssertEqual(uint8Value!, uint8)

        let cacheUInt16 = DiskCache<UInt16>()!
        defer { cacheUInt16.removeAll() }
        let uint16 = UInt16(UInt16.max)
        cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = cacheUInt16.value(forKey: "UInt16")
        XCTAssertNotNil(uint16Value)
        XCTAssertEqual(uint16Value!, uint16)

        let cacheUInt32 = DiskCache<UInt32>()!
        defer { cacheUInt32.removeAll() }
        let uint32 = UInt32(UInt32.max)
        cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = cacheUInt32.value(forKey: "UInt32")
        XCTAssertNotNil(uint32Value)
        XCTAssertEqual(uint32Value!, uint32)

        let cacheUInt64 = DiskCache<UInt64>()!
        defer { cacheUInt64.removeAll() }
        let uint64 = UInt64(UInt64.max)
        cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = cacheUInt64.value(forKey: "UInt64")
        XCTAssertNotNil(uint64Value)
        XCTAssertEqual(uint64Value!, uint64)
    }

    func testFloatingPoint() {
        let cacheFloat = DiskCache<Float>()!
        defer { cacheFloat.removeAll() }

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

        let cacheDouble = DiskCache<Double>()!
        defer { cacheDouble.removeAll() }

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
    extension DiskCacheTests {
        static var allTests : [(String, (DiskCacheTests) -> () throws -> Void)] {
            return [
                ("testDataValue", testDataValue),
                ("testStringValue", testStringValue),
                ("testRemove", testRemove),
                ("testRemoveAll", testRemoveAll),
                ("testKeyEncode", testKeyEncode),
                ("testFileCreation", testFileCreation),
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
