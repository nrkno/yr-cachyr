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

open class DiskCache<ValueType: DataConvertable> {
    /**
     Name of cache.
     Names should be unique enough to separate different caches.
     Reverse domain notation, like no.nrk.yr.cache, is a good choice.
     */
    public let name: String

    /**
     Queue used to synchronize disk cache access. The cache allows concurrent reads
     but only serial writes using barriers.
     */
    private let accessQueue = DispatchQueue(label: "no.nrk.yr.cache.disk.queue")

    /**
     Character set with all allowed file system characters. The ones not allowed are based on
     NTFS/exFAT limitations, which is a superset of HFS+ and most UNIX file system limitations.

     [Comparison of filename limitations](https://en.wikipedia.org/wiki/Filename#Comparison_of_filename_limitations)
     */
    private let allowedFilesystemCharacters: CharacterSet

    /**
     Name of extended attribute that stores expire date.
     */
    private let expireDateAttributeName = "no.nrk.yr.cachyr.expireDate"

    /**
     Storage for the url property.
     */
    private var _url: URL?

    /**
     URL of cache directory, of the form: `baseURL/name`
     */
    public private(set) var url: URL? {
        get {
            guard let url = _url else { return nil }
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                CacheLog.error("Unable to create \(url.path)")
                return nil
            }
            return url
        }
        set {
            _url = newValue
        }
    }

    /**
     The minimum amount of time elapsed before a new check for expired items is run.
     */
    public var checkExpiredInterval: TimeInterval = 10 * 60

    /**
     Returns true if enough time has lapsed to start a check for expired items.
     */
    public var shouldCheckExpired: Bool {
        return (Date().timeIntervalSince1970 - lastRemoveExpired.timeIntervalSince1970) > checkExpiredInterval
    }

    /**
     Last time expired items were removed.
     */
    public private(set) var lastRemoveExpired = Date(timeIntervalSince1970: 0)

    public init(name: String = "no.nrk.yr.cache.disk", baseURL: URL? = nil) {
        self.name = name

        var chars = CharacterSet(charactersIn: UnicodeScalar(0) ... UnicodeScalar(31)) // 0x00-0x1F
        chars.insert(UnicodeScalar(127)) // 0x7F
        chars.insert(charactersIn: "\"*/:<>?\\|")
        allowedFilesystemCharacters = chars.inverted

        if let baseURL = baseURL {
            self.url = baseURL.appendingPathComponent(name, isDirectory: true)
        } else {
            if let cachesURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                self.url = cachesURL.appendingPathComponent(name, isDirectory: true)
            } else {
                CacheLog.error("Unable to get system cache directory URL")
            }
        }
    }

    public func contains(key: String) -> Bool {
        if let url = fileURL(for: key) {
            return accessQueue.sync {
                return FileManager.default.fileExists(atPath: url.path)
            }
        }
        return false
    }

    public func value(forKey key: String) -> ValueType? {
        return accessQueue.sync {
            removeExpiredAfterInterval()

            guard let data = fileFor(key: key) else {
                return nil
            }

            if let value = ValueType.value(from: data) {
                return value
            } else {
                CacheLog.warning("Could not convert data to \(ValueType.self)")
                return nil
            }
        }
    }

    public func setValue(_ value: ValueType, forKey key: String, expires: Date? = nil) {
        accessQueue.sync {
            removeExpiredAfterInterval()

            guard let data = ValueType.data(from: value) else {
                CacheLog.warning("Could not convert \(value) to Data")
                return
            }
            addFile(for: key, data: data, expires: expires)
        }
    }

    public func removeValue(forKey key: String) {
        accessQueue.sync {
            removeFile(for: key)
        }
    }

    public func removeAll() {
        accessQueue.sync {
            guard let cacheURL = self.url else {
                return
            }
            do {
                try FileManager.default.removeItem(at: cacheURL)
            }
            catch let error {
                CacheLog.error(error.localizedDescription)
            }
        }
    }

    public func removeExpired() {
        accessQueue.sync {
            removeExpiredItems()
        }
    }

    public func expirationDate(forKey key: String) -> Date? {
        guard let url = fileURL(for: key) else {
            return nil
        }
        return accessQueue.sync {
            return expirationForFile(url)
        }
    }

    public func setExpirationDate(_ date: Date?, forKey key: String) {
        guard let url = fileURL(for: key) else {
            return
        }
        accessQueue.sync {
            setExpiration(date, for: url)
        }
    }

    public func removeItems(olderThan date: Date) {
        accessQueue.sync {
            guard let url = url else { return }
            let allFiles: [URL]
            do {
                allFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey])
            }
            catch let error {
                CacheLog.error(error.localizedDescription)
                return
            }

            allFiles.forEach { (fileUrl) in
                guard let resourceValues = try? fileUrl.resourceValues(forKeys: [.creationDateKey]) else { return }
                if let created = resourceValues.creationDate, created <= date {
                    removeFile(at: fileUrl)
                }
            }
        }
    }
    
    func encode(key: String) -> String {
        return key.addingPercentEncoding(withAllowedCharacters: allowedFilesystemCharacters)!
    }

    func decode(key: String) -> String {
        return key.removingPercentEncoding!
    }

    private func fileURL(for key: String) -> URL? {
        let encodedKey = encode(key: key)
        return self.url?.appendingPathComponent(encodedKey)
    }

    private func fileFor(key: String) -> Data? {
        guard let fileURL = fileURL(for: key) else {
            return nil
        }

        if fileExpired(fileURL: fileURL) {
            removeFile(for: key)
            return nil
        }

        return FileManager.default.contents(atPath: fileURL.path)
    }

    private func addFile(for key: String, data: Data, expires: Date? = nil) {
        guard let fileURL = fileURL(for: key) else {
            CacheLog.error("Unable to create file URL for \(key)")
            return
        }

        if !FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil) {
            CacheLog.error("Unable to create file at \(fileURL.path)")
            return
        }

        if let expires = expires {
            setExpiration(expires, for: fileURL)
        }
    }

    private func removeFile(for key: String) {
        guard let fileURL = fileURL(for: key) else {
            CacheLog.error("Unable to create file URL for '\(key)'")
            return
        }
        removeFile(at: fileURL)
    }

    private func removeFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        }
        catch let error {
            CacheLog.error(error.localizedDescription)
        }
    }

    /**
     Check expiration date extended attribute of file.
     */
    private func expirationForFile(_ url: URL) -> Date? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try FileManager.default.extendedAttribute(expireDateAttributeName, on: url)
            guard let epoch = Double.value(from: data) else {
                CacheLog.error("Unable to convert extended attribute data to expire date.")
                return nil
            }
            let date = Date(timeIntervalSince1970: epoch)
            return date
        } catch let error as ExtendedAttributeError {
            // Missing expiration attribute is not an error
            if error.code != ENOATTR {
                CacheLog.error("\(error.name) \(error.code) \(error.description)")
            }
        } catch {
            CacheLog.error("Error getting expire date extended attribute on \(url.path)")
        }

        return nil
    }

    /**
     Set expiration date of file as extended attribute. Set it to nil to remove it.
     */
    private func setExpiration(_ expiration: Date?, for file: URL) {
        guard let expires = expiration else {
            do {
                try FileManager.default.removeExtendedAttribute(expireDateAttributeName, from: file)
            } catch let error as ExtendedAttributeError {
                CacheLog.error("\(error.name) \(error.code) \(error.description) \(file.path)")
            } catch {
                CacheLog.error("Error removing expire date extended attribute on \(file.path)")
            }
            return
        }

        do {
            let epoch = expires.timeIntervalSince1970
            guard let data = Double.data(from: epoch) else {
                CacheLog.error("Unable to convert expiry date \(expires) to data")
                return
            }
            try FileManager.default.setExtendedAttribute(expireDateAttributeName, on: file, data: data)
        } catch let error as ExtendedAttributeError {
            CacheLog.error("\(error.name) \(error.code) \(error.description) \(file.path)")
        } catch {
            CacheLog.error("Error setting expire date extended attribute on \(file.path)")
        }
    }

    private func removeExpiredItems() {
        guard let url = url else { return }
        let allFiles: [URL]
        do {
            allFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        }
        catch let error {
            CacheLog.error(error.localizedDescription)
            return
        }

        let files = allFiles.filter { fileExpired(fileURL: $0) }
        for fileURL in files {
            removeFile(at: fileURL)
        }

        lastRemoveExpired = Date()
    }

    private func removeExpiredAfterInterval() {
        if !shouldCheckExpired {
            return
        }
        removeExpiredItems()
    }

    private func fileExpired(fileURL: URL) -> Bool {
        guard let date = expirationForFile(fileURL) else {
            return false
        }
        return date < Date()
    }
}
