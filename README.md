# Cachyr

A typesafe key-value data cache for iOS, macOS, tvOS and watchOS written in Swift.

There already exists plenty of cache solutions, so why create one more? We had a few requirements where existing solutions fulfilled some of them but not all:

- Written purely in Swift.
- Type safety while still allowing any kind of data to be stored.
- Disk and memory caching.
- Clean, single-purpose implementation. Do caching and nothing else.


## Installation

### CocoaPods

```
Add to Podfile:
pod 'Cachyr'

Then:
$ pod install
```

### Manual

Clone the repo somewhere suitable, like inside your project repo so Cachyr can be added as a subrepo, then drag `Cachyr.xcodeproj` into your project.

Alternatively build the framework and add it to your project.


## Usage

```swift
let cache = DataCache()
let key = "foo"
let text = "bar"
cache.setValue(text, for: key)

// ... do important things ...

let cachedText: String? = cache.value(for: key)

// Or asynchronously
let cachedText = cache.value(for: key) { (value: String?) in
    // Do something with value
}
```

In this example the string `bar` is stored in the cache for the key `foo`. It is later retrieved as a string optional by explicitly declaring `String?` as the value type. Let's look at how generics enable easy data transformation.

```swift
let textAsData = cache.value(for: key) { (value: Data?) in
    print(value)
}
```

Now the exact same key is used to retrieve the data representation of the value. The cache stores everything as data, and by implementing the `DataConvertable` protocol for a type it is possible to convert the cached data to the return type you define when retrieving a value.

There are default `DataConvertable` implementations for `Data`, `String`, `Int` (all integer types), `Float` and `Double`.

For detailed usage examples take a look at [Usage.md](./Docs/Usage.md).

## ToDo

This framework is production ready but there are still many possible improvements. Some known tasks are:

- Limit for disk usage. The disk cache has no limit on how much data it stores.
- Default `DataConvertable` support more common types.

Pull requests are very welcome.
