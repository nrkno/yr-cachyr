# Cachyr

A typesafe key-value data cache for iOS, macOS, tvOS and watchOS written in Swift.

There already exists plenty of cache solutions, so why create one more? We had a few requirements where existing solutions fulfilled some of them but not all:

- Written purely in Swift 3.
- Type safety while still allowing any kind of data to be stored.
- Disk and memory caching.
- Easy way to populate cache when a lookup results in a cache miss.
- Clean, single-purpose implementation. Do caching and nothing else.


## Installation

### CocoaPods

```
Add to Podfile:
pod 'Cachyr', :git => 'https://github.com/YR/Cachyr.git'

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

- Better thread synchronization. The cache uses serial dispatch queues to handle concurrent access and memory/disk value synchronization. This makes the code easy to follow and reason about, but it is not as performant as a solution using the multiple reader single writer pattern. We tried using concurrent dispatch queues with dispatch barriers for cache updates, but it got messy and code readability suffered. In early development serial queues were the way to go, but there is room for improvement.
- Limit for disk usage. The disk cache has no limit on how much data it stores.
- Default `DataConvertable` support more common types.
- Better way of storing expire date for files in the disk cache. The modification date is currently used, but this results in a limit of 2038-01-19 for 32-bit timestamps as used in HFS+.

Pull requests are very welcome.
