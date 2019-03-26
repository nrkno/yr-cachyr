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

public enum CacheLogLevel: Int {
    case verbose
    case debug
    case info
    case warning
    case error
}

public protocol CacheLogger {
    static func verbose(_ message: @autoclosure () -> Any, _ file: String, _ function: String, line: Int)
    static func debug(_ message: @autoclosure () -> Any, _ file: String, _ function: String, line: Int)
    static func info(_ message: @autoclosure () -> Any, _ file: String, _ function: String, line: Int)
    static func warning(_ message: @autoclosure () -> Any, _ file: String, _ function: String, line: Int)
    static func error(_ message: @autoclosure () -> Any, _ file: String, _ function: String, line: Int)
}

fileprivate let logLevelPrefix: [CacheLogLevel: String] = [
    .verbose: "VERBOSE",
    .debug  : "DEBUG",
    .info   : "INFO",
    .warning: "WARNING",
    .error  : "ERROR"
]

fileprivate let dateFormatter: DateFormatter = {
    var fmt = DateFormatter()
    fmt.dateFormat = "HH:mm:ss.SSS"
    return fmt
}()

public struct CacheLog {
    public static var logger: CacheLogger.Type? = nil

    public static var level: CacheLogLevel = .info

    public static func verbose(_ message: @autoclosure () -> Any, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        if let logger = CacheLog.logger {
            logger.verbose(message(), file, function, line: line)
        } else {
            log(level: .verbose, message: message(), file: file, function: function, line: line)
        }
    }

    public static func debug(_ message: @autoclosure () -> Any, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        if let logger = CacheLog.logger {
            logger.debug(message(), file, function, line: line)
        } else {
            log(level: .debug, message: message(), file: file, function: function, line: line)
        }
    }

    public static func info(_ message: @autoclosure () -> Any, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        if let logger = CacheLog.logger {
            logger.info(message(), file, function, line: line)
        } else {
            log(level: .info, message: message(), file: file, function: function, line: line)
        }
    }

    public static func warning(_ message: @autoclosure () -> Any, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        if let logger = CacheLog.logger {
            logger.warning(message(), file, function, line: line)
        } else {
            log(level: .warning, message: message(), file: file, function: function, line: line)
        }
    }

    public static func error(_ message: @autoclosure () -> Any, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        if let logger = CacheLog.logger {
            logger.error(message(), file, function, line: line)
        } else {
            log(level: .error, message: message(), file: file, function: function, line: line)
        }
    }

    private static func shouldLog(level: CacheLogLevel) -> Bool {
        return self.level.rawValue <= level.rawValue
    }

    private static func log(level: CacheLogLevel, message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog(level: level) else { return }

        let date = dateFormatter.string(from: Date())
        let pathComps = file.components(separatedBy: "/")
        let fileNameWithExt = pathComps.last ?? ""
        let fileName = fileNameWithExt.replacingOccurrences(of: ".swift", with: "")

        print("\(date) \(logLevelPrefix[level]!) \(fileName).\(function):\(line) \(message())")
    }
}
