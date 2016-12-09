# Usage

## The Basics

```swift
import Cachyr

// Creating a new cache is as simple as creating a `DataCache()` instance.
// You can optionally give it a name, set a completion queue for async functions,
// and provide a URL for its location on disk.

let cache = DataCache()

// Modifying the cache synchronously is straighforward but blocks
// the calling thread.

let key = "foo"
let bar = "bar"

cache.setValue(bar, for: key)
var text: String? = cache.value(for: key)

// All cache modification functions can be called asynchronously by providing
// a completion closure.

cache.value(for: key) { (value: String?) in
    print(value)
}

// Value removal

cache.removeValue(for: key)

cache.removeValue(for: key) {
	print("Value removed.")
}

// Expiration

// Expires in 10 seconds
let futureDate = Date(timeIntervalSinceNow: 10)
cache.setValue(bar, for: key, expires: futureDate)
```

## Data Transformation

The cache stores everything as raw data on disk, which means type information is lost. In order to retrieve the data as a specific type the type must conform to the `DataConvertable` protocol. The cache functions are generic and will try to fetch the value as whatever type you define as the return type.

```swift
// Data, String, Int, Float and Double have default
// DataConvertable implementations.

let key = "foo"
let barData = "bar".data(using: .utf8)!
cache.setValue(barData, for: key)
let data: Data? = cache.value(for: key)
let text: String? = cache.value(for: key)
```

Let's try something more advanced. Here is a JSON response retrieved from the cache as data, JSON string, and model object:

```swift
struct Book {
    let title: String
}

extension Book: DataConvertable {
    static func data(from value: Book) -> Data? {
        let json: [String: Any] = ["title": value.title]
        let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: .prettyPrinted)
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

let weaveworld = Book(title: "Weaveworld")
let key = "book"
cache.setValue(weaveworld, for: key)

let data: Data? = cache.value(for: key)
print("Data length: \(data.length)")

let text: String? = cache.value(for: key)
print("JSON string: \(text)")

let book: Book? = cache.value(for: key)
print("Book title: \(book.title)")
```

## Data Source

The data cache can have an optional data source assigned, which must conform to the `CacheDataSource` protocol. Whenever the cache is asynchronously queried for a value and the value is not found, the cache will query the data source if one has been assigned. When the data source returns with a value it will be stored in the cache and the completion closure for the query will be run, as well as all completions waiting in queue for the value.

This is a powerful feature that can for instance be used to automatically populate the cache with JSON or image data from the network by using keys that can be translated to network resources.

The following example demonstrates a data source that returns the key as the value.

```swift
class StringDataSource: CacheDataSource {
    var wait = 0.0

    func data(for key: String, completion: @escaping (Data?, Date?) -> Void) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + wait) {
            let data = key.data(using: .utf8)
            completion(data, nil)
        }
    }
}

cache.removeAll()
cache.dataSource = StringDataSource()
let key = "veryUniqueKey"
cache.value(for: key) { (value: String?) in
    print(value)
}
```
