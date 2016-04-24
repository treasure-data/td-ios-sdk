# TreasureData iOS SDK

iOS SDK for [TreasureData](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into TreasureData easily.

## Requirements
* iOS 8.0+
* Xcode 7.3+

## Installation

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

To integrate TreasureDataSDK into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "uny/TreasureDataSDK"
```

Run `carthage update` to build the framework and drag the built `TreasureDataSDK.framework` into your Xcode project.

## Usage

### Configuration

|name|description|
|---|---|
|debug|[OPTIONAL] Enable debug log to console. The default is false.|
|endpoint|[OPTIONAL] TreasureData API endpoint. The default is "https://in.treasuredata.com".|
|key|[REQUIRED] TreasureData API key.|
|database|[REQUIRED] TreasureData database name you want to send.|
|table|[REQUIRED] TreasureData table name you want to send.|
|fileURL|[OPTIONAL] Local URL to the realm file. The default is in Application Support directory. Mutually exclusive with inMemoryIdentifier.|
|inMemoryIdentifier|[OPTIONAL] A string used to identify a particular in-memory Realm. Mutually exclusive with path.|
|encriptionKey|[OPTIONAL] 64-byte key to use to encrypt the data.|
|shouldAppendDeviceIdentifier|[OPTIONAL] Automatically appended device identifier if it is true. The default is false.|
|shouldAppendModelInformation|[OPTIONAL] Automatically appended device information if it is true. The default is false.|
|shouldAppendSeverSideTimestamp|[OPTIONAL] Request append server side timestamp if it is true. The default is false.|

### New Instance / Default Instance

You can create new instances for each database/table, and use a default instance.

```swift
// new instance
let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE")
let instance = TreasureData(configuration: configuration)

// default instance
TreasureData.configure(configuration)
```

### Add Events to Local Buffer

You can append extra information by passing dictionary.
**Only `[String: String]` can be accepted.**

```swift
// each instance
let userInfo: [String: String] = [
  "Key": "Value"
]
instance.addEvent(userInfo: userInfo)

// default instance
TreasureData.addEvent()
```

### Upload Buffered Events to TreasureData

```swift
func applicationDidEnterBackground(application: UIApplication) {
  self.taskIdentifier = application.beginBackgroundTaskWithExpirationHandler {
    application.endBackgroundTask(self.taskIdentifier)
    self.taskIdentifier = UIBackgroundTaskInvalid
  }
  TreasureData.uploadEvents { result in
    application.endBackgroundTask(self.taskIdentifier)
    self.taskIdentifier = UIBackgroundTaskInvalid
  }
}

func applicationDidBecomeActive(application: UIApplication) {
  application.endBackgroundTask(self.taskIdentifier)
}
```

### Start/End Session

When you call `startSession` method,  the SDK generates a session ID that's kept until `endSession` is called. The session id is outputs as a column name "td_session_id".

```swift
// Start
TreasureData.startSession()

// End
TreasureData.endSession()
```
