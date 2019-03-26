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

public protocol DataConvertable {
    static func data(from value: Self) -> Data?
    static func value(from data: Data) -> Self?
}

extension Data: DataConvertable {
    public static func data(from value: Data) -> Data? {
        return value
    }

    public static func value(from data: Data) -> Data? {
        return data
    }
}

extension String: DataConvertable {
    public static func data(from value: String) -> Data? {
        return value.data(using: .utf8, allowLossyConversion: false)
    }

    public static func value(from data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}

extension BinaryInteger {
    public static func data(from value: Self) -> Data? {
        var theValue = value
        return Data(buffer: UnsafeBufferPointer(start: &theValue, count: 1))
    }

    public static func value(from data: Data) -> Self? {
        guard data.count == MemoryLayout<Self>.size else {
            return nil
        }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Self? in
            let raw = ptr.bindMemory(to: Self.self)
            return raw.first
        }
    }
}

extension Int: DataConvertable {}
extension Int8: DataConvertable {}
extension Int16: DataConvertable {}
extension Int32: DataConvertable {}
extension Int64: DataConvertable {}
extension UInt: DataConvertable {}
extension UInt8: DataConvertable {}
extension UInt16: DataConvertable {}
extension UInt32: DataConvertable {}
extension UInt64: DataConvertable {}

extension Float: DataConvertable {
    public static func data(from value: Float) -> Data? {
        return UInt32.data(from: value.bitPattern)
    }

    public static func value(from data: Data) -> Float? {
        guard let pattern = UInt32.value(from: data) else { return nil }
        return Float(bitPattern: pattern)
    }
}

extension Double: DataConvertable {
    public static func data(from value: Double) -> Data? {
        return UInt64.data(from: value.bitPattern)
    }

    public static func value(from data: Data) -> Double? {
        guard let pattern = UInt64.value(from: data) else { return nil }
        return Double(bitPattern: pattern)
    }
}
