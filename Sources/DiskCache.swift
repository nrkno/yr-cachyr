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
     Name of cache. Must be unique to separate different caches.
     Reverse domain notation, like no.nrk.yr.cache, is a good choice.
     */
    public let name: String

    /**
     Queue used to synchronize disk cache access. The cache allows concurrent reads
     but only serial writes using barriers.
     */
    private let accessQueue: DispatchQueue

    /**
     Name of extended attribute that stores expire date (DEPRECATED).
     */
    private let expireDateAttributeName = "no.nrk.yr.cachyr.expireDate"

    /**
     Name of the extended attribute that holds the key (DEPRECATED).
     */
    private let keyAttributeName = "no.nrk.yr.cachyr.key"

    /**
     Metadata and storage name for keys.
     */
    private var storageKeyMap = [String: CacheItem]()

    /**
     Storage for the url property.
     */
    private let _url: URL

    /**
     URL of cache directory, of the form: `baseURL/name`
     */
    public var url: URL? {
        do {
            try FileManager.default.createDirectory(at: _url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            CacheLog.error("Unable to create \(_url.path):\n\(error)")
            return nil
        }
        return _url
    }

    /**
     URL of DB file with metadata for all cache items.
     */
    private var dbFileURL: URL

    /**
     The number of bytes used by the contents of the cache.
     */
    public var storageSize: Int {
        return accessQueue.sync {
            guard let url = self.url else {
                return 0
            }

            let fm = FileManager.default
            var size = 0

            do {
                let files = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
                size = files.reduce(0, { (totalSize, url) -> Int in
                    let attributes = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
                    let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
                    return totalSize + fileSize
                })
            } catch {
                CacheLog.error("\(error)")
            }

            return size
        }
    }

    public init?(name: String = "no.nrk.yr.cache.disk", baseURL: URL? = nil) {
        self.name = name

        let fm = FileManager.default

        if let baseURL = baseURL {
            _url = baseURL.appendingPathComponent(name, isDirectory: true)
        } else {
            do {
                let cachesURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                _url = cachesURL.appendingPathComponent(name, isDirectory: true)
            } catch {
                CacheLog.error(error)
                return nil
            }
        }

        do {
            let appSupportName = "no.nrk.yr.cachyr"
            let appSupportURL = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let appURL = appSupportURL.appendingPathComponent(appSupportName, isDirectory: true)
            try fm.createDirectory(at: appURL, withIntermediateDirectories: true)
            dbFileURL = appURL.appendingPathComponent("\(name).json", isDirectory: false)
        } catch {
            CacheLog.error(error)
            return nil
        }

        accessQueue = DispatchQueue(label: "\(name).queue", attributes: .concurrent)

        // Ensure URL path exists or can be created
        guard let _ = self.url else {
            return nil
        }

        loadStorageKeyMap()
    }

    deinit {
        saveDB()
    }

    public func contains(key: String) -> Bool {
        return accessQueue.sync {
            return _contains(key: key)
        }
    }

    private func _contains(key: String) -> Bool {
        guard let url = fileURL(forKey: key) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func value(forKey key: String) -> ValueType? {
        return accessQueue.sync {
            guard let data = data(for: key) else {
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
        accessQueue.sync(flags: .barrier) {
            guard let data = ValueType.data(from: value) else {
                CacheLog.warning("Could not convert \(value) to Data")
                return
            }
            addFile(for: key, data: data, expires: expires)
        }
    }

    public func removeValue(forKey key: String) {
        accessQueue.sync(flags: .barrier) {
            removeFile(for: key)
        }
    }

    public func removeAll() {
        accessQueue.sync(flags: .barrier) {
            _removeAll()
        }
    }

    private func _removeAll() {
        storageKeyMap.removeAll()
        saveDB()
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

    public func removeExpired() {
        accessQueue.sync(flags: .barrier) {
            removeExpiredItems()
        }
    }

    private func removeExpiredItems() {
        storageKeyMap.values
            .filter { $0.hasExpired }
            .forEach { removeFile(for: $0.key) }
    }

    public func expirationDate(forKey key: String) -> Date? {
        return accessQueue.sync {
            return _expirationDate(for: key)
        }
    }

    private func _expirationDate(for key: String) -> Date? {
        return storageKeyMap[key]?.expirationDate
    }

    public func setExpirationDate(_ date: Date?, forKey key: String) {
        accessQueue.sync(flags: .barrier) {
            _setExpirationDate(date, forKey: key)
        }
    }

    private func _setExpirationDate(_ date: Date?, forKey key: String) {
        storageKeyMap[key]?.expirationDate = date
        saveDBAfterInterval()
    }

    public func removeItems(olderThan date: Date) {
        accessQueue.sync(flags: .barrier) {
            _removeItems(olderThan: date)
        }
    }

    private func _removeItems(olderThan date: Date) {
        for item in storageKeyMap.values {
            guard
                let fileURL = fileURL(forKey: item.key),
                let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                let created = resourceValues.creationDate,
                created <= date
            else {
                continue
            }
            removeFile(for: item.key)
        }
    }

    func fileURL(forItem item: CacheItem) -> URL? {
        return fileURL(forName: item.uuid.uuidString)
    }

    func fileURL(forKey key: String) -> URL? {
        guard let item = storageKeyMap[key] else { return nil }
        return fileURL(forItem: item)
    }

    func fileURL(forName name: String) -> URL? {
        guard let url = self.url else { return nil }
        return url.appendingPathComponent(name, isDirectory: false)
    }

    private func data(for key: String) -> Data? {
        guard
            let item = storageKeyMap[key],
            let fileURL = fileURL(forItem: item)
        else {
            return nil
        }

        if item.hasExpired {
            accessQueue.async(flags: .barrier) {
                self.removeFile(for: key)
            }
            return nil
        }

        return FileManager.default.contents(atPath: fileURL.path)
    }

    private func filesInCache(properties: [URLResourceKey]? = [.nameKey]) -> [URL] {
        guard let url = self.url else {
            return []
        }

        do {
            let fm = FileManager.default
            let files = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: properties, options: [.skipsHiddenFiles])
            return files
        } catch {
            CacheLog.error("\(error)")
            return []
        }
    }

    private func addFile(for key: String, data: Data, expires: Date? = nil) {
        let cacheItem: CacheItem

        if let existingItem = storageKeyMap[key] {
            cacheItem = existingItem
            storageKeyMap[key]!.expirationDate = expires
        } else {
            cacheItem = CacheItem(key: key, uuid: UUID(), expirationDate: expires)
            storageKeyMap[key] = cacheItem
        }

        let fm = FileManager.default

        guard
            let fileURL = self.fileURL(forItem: cacheItem),
            fm.createFile(atPath: fileURL.path, contents: data, attributes: nil)
        else {
            CacheLog.error("Unable to create file for \(key)")
            removeFile(for: key)
            return
        }

        saveDBAfterInterval()
    }

    private func removeFile(for key: String) {
        if let fileURL = fileURL(forKey: key) {
            removeFile(at: fileURL)
        }
        storageKeyMap[key] = nil
        saveDBAfterInterval()
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
     Check expiration date extended attribute of file (DEPRECATED).
     */
    private func xattrExpirationForFile(_ url: URL) -> Date? {
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
     Get key from extended attribute of file (DEPRECATED).
     */
    private func xattrKeyForFile(_ url: URL) -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return nil
        }

        var key: String?
        do {
            let data = try fm.extendedAttribute(keyAttributeName, on: url)
            key = String(data: data, encoding: .utf8)
            if key == nil {
                CacheLog.error("Unable to decode key from data for extended attribute '\(keyAttributeName)'")
            }
        } catch {
            CacheLog.error("Extended attribute '\(keyAttributeName)' not found on \(url.absoluteString)\n\(error)")
        }

        return key
    }

    /**
     Reset storage key map and load all keys from files in cache.
     */
    private func loadStorageKeyMap() {
        loadDB()

        migrateXattrFiles()

        validateDB()

        saveDB()
    }

    private func loadDB() {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: dbFileURL.path) else {
            return
        }
        let decoder = JSONDecoder()
        do {
            storageKeyMap = try decoder.decode([String: CacheItem].self, from: data)
        } catch {
            CacheLog.error(error)
        }
    }

    private var lastDBSaveDate = Date(timeIntervalSince1970: 0)

    private func saveDB() {
        let fm = FileManager.default
        let encoder = JSONEncoder()

        do {
            let data = try encoder.encode(storageKeyMap)
            if fm.createFile(atPath: dbFileURL.path, contents: data, attributes: nil) {
                lastDBSaveDate = Date()
            }

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try dbFileURL.setResourceValues(resourceValues)
        } catch {
            CacheLog.error(error)
            return
        }
    }

    private var lastDBSaveTriggeredDate = Date(timeIntervalSince1970: 0)

    private let maxDBSaveInterval: TimeInterval = 5.0

    private func saveDBAfterInterval(_ interval: TimeInterval = 2.0) {
        let triggerDate = Date()
        lastDBSaveTriggeredDate = triggerDate
        accessQueue.asyncAfter(deadline: .now() + interval, flags: .barrier) {
            let latestDate = self.lastDBSaveDate.addingTimeInterval(self.maxDBSaveInterval)
            let now = Date()
            if now >= latestDate || self.lastDBSaveTriggeredDate == triggerDate {
                self.saveDB()
            }
        }
    }

    private func validateDB() {
        let fm = FileManager.default

        // Make sure each item has a corresponding file
        for item in storageKeyMap.values {
            guard
                !item.hasExpired,
                let fileURL = fileURL(forItem: item),
                fm.fileExists(atPath: fileURL.path)
            else {
                removeFile(for: item.key)
                continue
            }
        }

        // Make sure each file has a corresponding item
        let items = storageKeyMap.values
        for fileURL in filesInCache() {
            let fileName = fileURL.lastPathComponent
            if items.contains(where: { $0.uuid.uuidString == fileName }) {
                continue
            }
            try? fm.removeItem(at: fileURL)
        }
    }

    private func migrateXattrFiles() {
        for fileURL in filesInCache() {
            guard let xattrKey = xattrKeyForFile(fileURL) else {
                continue
            }

            let expiration = xattrExpirationForFile(fileURL)
            let item = CacheItem(key: xattrKey, uuid: UUID(), expirationDate: expiration)
            let fm = FileManager.default

            guard let destinationURL = self.fileURL(forItem: item) else {
                try? fm.removeItem(at: fileURL)
                continue
            }

            do {
                try fm.removeExtendedAttribute(keyAttributeName, from: fileURL)
                try fm.removeExtendedAttribute(expireDateAttributeName, from: fileURL)
                try fm.moveItem(at: fileURL, to: destinationURL)
            } catch {
                CacheLog.error(error)
                try? fm.removeItem(at: fileURL)
                continue
            }

            storageKeyMap[xattrKey] = item
        }
    }
}
