Treasure Data iOS SDK
===============

iOS and tvOS SDK for [Treasure Data](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into Treasure Data easily. As of 0.9.0, this SDK support iOS 12 and up as well as support tvOS 12 and up.

## Migration to version 1

Version 1 has major changes that are not backward compatible with previous versions. If you are upgrading from version 0.9.0 or earlier, your code will not run correctly without doing these following steps:
- API endpoint has changed to Ingestion Endpoint. The default value is https://us01.records.in.treasuredata.com.
- `initializeApiEndpoint:` API is no longer available, please use `initializeWithApiKey:apiEndpoint:` instead.
- Server side upload timestamp feature is removed.
- New `enableAutoAppendLocalTimestamp` and `disableAutoAppendLocalTimestamp` to help automatically track local timestamp.
- `uuid` is now reserved column name. If you try to add value to event's `uuid` key, you won't see the column show up in the database.
- Auto tracking of client id by adding `td_ip` field is no longer supported. Instead, use new `enableAutoTrackingIP` and `disableAutoTrackingIP` APIs.

## Usage in Swift

See this example project (https://github.com/treasure-data/td-ios-sdk/tree/master/TreasureDataExampleSwift) for details.

## Installation

There are several ways to install the library.

### CocoaPods

[CocoaPods](http://cocoapods.org/) is needed to set up the SDK. If you've not installed it yet, install it at first.

```
$ gem install cocoapods
```

Next, add this line in your Podfile.

```
pod 'TreasureData-iOS-SDK', '= 1.2.1'
```

Add this line to your Podfile (usually at the beginning of the file).
```
use_frameworks!
```

Finally, execute 'pod install'.

```
$ pod install
```

Remember to reopen your project by opening .xcworkspace file instead of .xcodeproj file 

### Swift Package Manager

You can install either via Xcode: File > Swift Packages > Add Package Dependency and enter `https://github.com/treasure-data/td-ios-sdk.git`.

Or add this line to `dependencies` array in Package.swift file:
```
.package(url: "https://github.com/treasure-data/td-ios-sdk.git", .upToNextMajor(from: "1.2.1"))
```

### Framework

From 0.9.0, we no longer support standalone framework.

## Usage in Objective-C

- [Treasure Data's Guide](https://docs.treasuredata.com/display/public/PD/iOS+SDK) (most parts overlap with this README)
- [API Reference](https://treasure-data.github.io/td-ios-sdk/Classes/TreasureData.html)

### Import SDK header file

```
#import <TreasureData-iOS-SDK/TreasureData.h>
```


### Register your TreasureData API key

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [TreasureData initializeWithApiKey:@"your_api_key"];
}
```

We recommend to use a write-only API key for the SDK. To obtain one, please:

1. Login into the Treasure Data Console at http://console.treasuredata.com;
2. Visit your Profile page at http://console.treasuredata.com/users/current;
3. Insert your password under the 'API Keys' panel;
4. In the bottom part of the panel, under 'Write-Only API keys', either copy the API key or click on 'Generate New' and copy the new API key.

### Add an event to local buffer

To add an event to local buffer, you can call `TreasureData`'s `addEvent` or `addEventWithCallback` API.


```
- (IBAction)clickButton:(id)sender {
    [[TreasureData sharedInstance] addEventWithCallback:@{
                       @"name": @"boo bar",
                       @"age": @42,
                       @"comment": @"hello world"
                   }
                   database:@"testdb"
                      table:@"demotbl"
                  onSuccess:^(){
                      NSLog(@"addEvent: success");
                  }
                    onError:^(NSString* errorCode, NSString* message) {
                        NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
                    }];
                    
    // Or, simply...
    //   [[TreasureData sharedInstance] addEvent:@{
    //                     @"name": @"boo bar",
    //                     @"age": @42,
    //                     @"comment": @"hello world"
    //                 }
    //                 database:@"testdb"
    //                    table:@"demotbl"];
```


Specify the database and table to which you want to import the events. The total length of database and table must be shorter than 129 chars. Each table will cache no more than 10000 events.

On top of that, the length of key in event must not exceed 256 chars and the length of value in event must not exceed 10000 chars.

### Upload buffered events to TreasureData

To upload events buffered events to Treasure Data, you can call `TreasureData`'s `uploadEvents` or `uploadEventsWithCallback` API.

```
- (void)applicationDidEnterBackground:(UIApplication *)application {
	__block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
		[application endBackgroundTask:bgTask];
		bgTask = UIBackgroundTaskInvalid;
	}];

    // You can call this API to uplaod buffered events whenever you want.
	[[TreasureData sharedInstance] uploadEventsWithCallback:^() {
			[application endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
		onError:^(NSString *code, NSString *msg) {
			[application endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
	];

    // Or, simply...
    //  [[TreasureData sharedInstance] uploadEvents];

```

It depends on the characteristic of your application when to upload and how often to upload buffered events. But we recommend the followings at least as good timings to upload.

- When the current screen is closing or moving to background
- When closing the application

The sent events is going to be buffered for a few minutes before they get imported into Treasure Data storage.

In tvOS, cache storage is stored in cache directory which can be purged at any time. It is highly recommended to call upload events APIs as requently as possible to prevent loss of data.

### Retry uploading and deduplication

This SDK imports events in exactly once style with the combination of these features.

- This SDK keeps buffered events with adding unique keys and retries to upload them until confirming the events are uploaded and stored on server side (at least once)
- The server side remembers the unique keys of all events within the past 1 hours by default and prevents duplicated imports (at most once)

As for the deduplication window is 1 hour by default, so it's important not to keep buffered events more than 1 hour to avoid duplicated events.

### Default values

Set a default value if you want an event added to a table, a database, or any table or database to automatically set value for a key.
If you have multiple default values set to the same key, newly added event will have the default value applied and override in following order:
1. Default value targeting all table and database will be applied first.
2. Default value targeting all table in a database will then be applied.
3. Default value targeting the table to which the event is added will then be applied.
4. Default value targeting the table and database to which the event is added will then be applied.
5. Finally, if the event has a value for the key, that value will override all default values.

To set default value:
```
[[TreasureData sharedInstance] setDefaultValue:@"Value" forKey:@"key" database:nil table:nil]; // Targeting all databases and tables
[[TreasureData sharedInstance] setDefaultValue:@"Value" forKey:@"key" database:"database_name" table:nil]; // Targeting all tables of database "database_name"
[[TreasureData sharedInstance] setDefaultValue:@"Value" forKey:@"key" database:nil table:"table_name"]; // Targeting all tables with "table_name"
[[TreasureData sharedInstance] setDefaultValue:@"Value" forKey:@"key" database:"database_name" table:"table_name"]; // Targeting table "table_name" of database "database_name"
```

To get default value:
```
NSString *defaultValue = [[TreasureData sharedInstance] defaultValueForKey:@"key" database:"database_name" table:"table_name"]; // Get default value for key targeting database "database_name" and table "table_name".
```

To remove default value:
```
[[TreasureData sharedInstance] removeDefaultValueForKey:@"key" database:"database_name" table:"table_name"]; // Only remove default values targeting database "database_name" and table "table_name".
```

### Start/End session

When you call `startSession` method,  the SDK generates a session ID that's kept until `endSession` is called. The session id is outputs as a column name "td_session_id". Also, `startSession` and `endSession` methods add an event that includes `{"td_session_event":"start" or "end"}`.

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[TreasureData initializeWithApiKey:@"your_api_key"];
	[[TreasureData sharedInstance] setDefaultDatabase:@"testdb"];
	[[TreasureData sharedInstance] startSession:@"demotbl"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[[TreasureData sharedInstance] endSession:@"demotbl"];

	__block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
		[application endBackgroundTask:bgTask];
		bgTask = UIBackgroundTaskInvalid;
	}];

	[[TreasureData sharedInstance] uploadEventsWithCallback:^() {
			[application endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
		onError:^(NSString *code, NSString *msg) {
			[application endBackgroundTask:bgTask];
			bgTask = UIBackgroundTaskInvalid;
		}
		// Outputs =>>
		//   [{"td_session_id":"cad88260-67b4-0242-1329-2650772a66b1",
		//		"td_session_event":"start", "time":1418880000},
		//
		//    {"td_session_id":"cad88260-67b4-0242-1329-2650772a66b1",
		//		"td_session_event":"end", "time":1418880123}
		//    ]
	];
```

If you want to handle the following case, use a pair of class methods `startSession` and `endSession` for global session tracking

- User opens the application and starts session tracking using `startSession`. Let's call this session session#0
- User moves to home screen and finishes the session using `endSession`
- User reopens the application and restarts session tracking within default 10 seconds. But you want to deal with this new session as the same session as session#0

```
- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[TreasureData startSession];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[TreasureData endSession];
}
```

In this case, you can get the current session ID using `getSessionId` class method

```
- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[TreasureData startSession];
    NSLog(@"Session ID=%@", [TreasureData getSessionId]);
}
```

### Detect if it's the first running

You can detect if it's the first running or not easily using `isFirstRun` method and then clear the flag with `clearFirstRun`.

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
		:
    if ([[TreasureData sharedInstance] isFirstRun]) {
        [[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"installed" }
                               database:@"testdb"
                                  table:@"demotbl"
                              onSuccess:^(){
                                  [[TreasureData sharedInstance] uploadEventsWithCallback:^() {
                                      [[TreasureData sharedInstance] clearFirstRun];
                                    }
                                    onError:^(NSString* errorCode, NSString* message) {
                                      NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
                                    }
                                   ];
                                }
                                onError:^(NSString* errorCode, NSString* message) {
                                    NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
                                }];
    }
```



## About Error code

`addEventWithCallback` and `uploadEventsWithCallback` methods call back `onError` block with `errorCode` argument. This argument is useful to know the cause type of the error. There are the following error codes.

- `init_error` :  The initialization failed.
- `invalid_param` : The parameter passed to the API was invalid
- `invalid_event` : The event was invalid
- `data_conversion` : Failed to convert the data to/from JSON
- `storage_error` : Failed to read/write data in the storage
- `network_error` : Failed to communicate with the server due to network problem
- `server_response` : The server returned an error response


## Additional Configuration

### Endpoint

The API endpoint (default: https://us01.records.in.treasuredata.com) can be specify using `+[TreasureData initializeWithApiKey:apiEndpoint]`

```
[TreasureData initializeWithApiKey:@"your_api_key" apiEndpoint: @"https://specifying-another-endpoint.com"];
```

### Encryption key

If you've set an encryption key via `initializeEncryptionKey` class method, our SDK saves the events data as encrypted when called `addEvent` or `addEventWithCallback` methods.

```
[TreasureData initializeEncryptionKey:@"hello world"];

[[TreasureData sharedInstance] addEventWithCallback: ....];
```

### Default database

```
[[TreasureData sharedInstance] setDefaultDatabase:@"testdb"];

[[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"clicked" } table:@"demotbl"]
```

### Adding UUID of the device to each event automatically
UUID of the device will be added to each event automatically if you call `enableAutoAppendUniqId`. This value won't change until the application is uninstalled or  `resetUniqId` is called. 

```
[[TreasureData sharedInstance] enableAutoAppendUniqId];
```

It outputs the value as a column name `td_uuid`.

### Get UUID and Reset UUID
You can get current UUID (`td_uuid`) at any time using following API. Remember that this UUID will change if  `resetUniqId` is called.
```
NSString *td_uuid = [[TreasureData sharedInstance] getUUID];
```

You can also reset UUID (`td_uuid`) at any time using following API. 
```
[[TreasureData sharedInstance] resetUniqId];
```

### Adding local time to each even record automatically (enabled by default)
By default, local timestamp will be added to event's `time` key automatically. If you `disableAutoAppendLocalTimestamp` without adding `time` key to the event yourself, the server will add server side timestamp to `time` column. You can also auto track local time with custom column. If so, the `time` column will have server side timestamp.

```
// Use local time as `time` column
[[TreasureData sharedInstance] enableAutoAppendLocalTimestamp];

// Add local time as a customized column name
[[TreasureData sharedInstance] enableAutoAppendLocalTimestamp:@"clientside_time"];

// Disable auto append local time
[[TreasureData sharedInstance] disableAutoAppendLocalTimestamp];
```

### Adding an UUID to each event record automatically
UUID will be added to each event record automatically if you call `enableAutoAppendRecordUUID`. Each event has different UUID.

```
[[TreasureData sharedInstance] enableAutoAppendRecordUUID];

// If you want to customize the column name, pass it to the API
[[TreasureData sharedInstance] enableAutoAppendRecordUUID:@"my_record_uuid"];
```

It outputs the value as a column name `record_uuid` by default.

### Adding Advertising Id to each event record automatically
Advertising Id will be added to each event record automatically if you call `enableAutoAppendAdvertisingIdentifier`.

You must link Ad Support framework in Link Binary With Libraries build phase for this feature to work. User must also not turn on Limit Ad Tracking feature in their iOS device, otherwise Treasure Data will send zero filled string as the advertising id (the value we get from Ad Support framework).

Starting in iOS 14, you will have to explicitly request user's permission for advertising identifier using AppTrackingTransparency framework. Consult Apple official documentation for AppTrackingTransparency on how to implement this requirement.

If you turn on this feature, keep in mind that you will have to declare correct reason for getting advertising identifier when you submit your app for review to the App Store.

```
[[TreasureData sharedInstance] enableAutoAppendAdvertisingIdentifier];

// If you want to customize the column name, pass it to the API
[[TreasureData sharedInstance] enableAutoAppendAdvertisingIdentifier:@"custom_ad_id_column"];
```

It outputs the value as a column name `td_maid` by default.


### Adding the device model information to each event automatically
Device model infromation will be added to each event automatically if you call `enableAutoAppendModelInformation`.

```
[[TreasureData sharedInstance] enableAutoAppendModelInformation];
```

It outputs the following column names and values:

- `td_device` : UIDevice.model
- `td_model` : UIDevice.model
- `td_os_ver` : UIDevice.model.systemVersion
- `td_os_type` : "iOS"

### Adding application version information to each event automatically

Application version infromation will be added to each event automatically if you call `enableAutoAppendAppInformation`.

```
[[TreasureData sharedInstance] enableAutoAppendAppInformation];
```

It outputs the following column names and values:

- `td_app_ver` : Core Foundation key `CFBundleShortVersionString`
- `td_app_ver_num` : Core Foundation key `CFBundleVersion`

### Adding locale configuration information to each event automatically

Locale configuration infromation will be added to each event automatically if you call `enableAutoAppendLocaleInformation`.

```
[[TreasureData sharedInstance] enableAutoAppendLocaleInformation];
```

It outputs the following column names and values:

- `td_locale_country` : `[[NSLocale currentLocale] objectForKey: NSLocaleCountryCode]`
- `td_locale_lang` : `[[NSLocale currentLocale] objectForKey: NSLocaleLanguageCode]`

### Auto tracking device IP

Device IP will be added to each event automatically in `td_ip` column if you call `enableAutoTrackingIP`. Note that the tracked IP address is the one when you upload the events to Treasure Data, not the one when you add the event.

```
[[TreasureData sharedInstance] enableAutoTrackingIP];
```

To disable auto tracking IP:

```
[[TreasureData sharedInstance] disableAutoTrackingIP];
```

### Enable/Disable debug log

```
[TreasureData enableLogging];
```

```
[TreasureData disableLogging];
```

### Automatically tracked events

Notes that all of these are **disabled by default*, you have to explicitly enable it for each category.

#### App Lifecycle Events

Could be enabled with:

```
[[TreasureData sharedInstance] enableAppLifecycleEvent];
```

There are 3 type of app lifecycle events that are tracked: `TD_IOS_APP_OPEN`, `TD_IOS_APP_INSTALL` and `TD_IOS_APP_UPDATE` (is written to `td_ios_event` column).

Example of a tracked install event:

```
"td_ios_event" = "TD_IOS_APP_INSTALL";
"td_app_ver" = "1.1";
"td_app_ver_num" = 2;
```

#### In-App Purchase Events

TreasureData SDK is able to automatically track IAP `SKPaymentTransactionStatePurchased` event without having to write your own transaction observer.


```
[[TreasureData sharedInstance] enableInAppPurchaseEvent];
```

This is disabled by default. There is a subtle difference between this and `appLifecycleEvent`, `customEvent`. The other two, for a historical reason, are persistent settings, meaning their statuses are saved across app launches. `inAppPurchaseEvent` behaves like an ordinary object option and is not saved. You have to enable it after initialize your new `TreasureData` instance (probably only the `sharedInstance` with `initializeWithApiKey`).

An example of a IAP event:

```
"td_ios_event": "TD_IOS_IN_APP_PURCHASE",
"td_iap_transaction_identifier": "1000000514091400",
"td_iap_transaction_date": "2019-03-28T08:44:12+07:00",
"td_iap_quantity": 1,
"td_iap_product_identifier": "com.yourcompany.yourapp.yourproduct", ,
"td_iap_product_price": 0.99,
"td_iap_product_localized_title": "Your Product Title",
"td_iap_product_localized_description": "Your Product Description",
"td_iap_product_currency_code": "USD",  // this is only available on iOS 10 and above
```

We will do a separated `SKProductsRequest` to get full product's information. If the request is failed somehow, fields with "td_iap_product_" prefix will be null. Also note that that the `currency_code` is only available from iOS 10 onwards.

#### Profile API

##### fetchUserSegments

This feature is not enabled on accounts by default, please contact support for more information.
Important! You must set cdpEndpoint property of TreasureData's sharedInstance.
Usage example:
```
// Set cdpEndpoint when initialize TreasureData  
[[TreasureData sharedInstance] setCdpEnpoint: @"[your cdp endpoint goes here]"]

// Call fetchUserSegments to get user segments as NSArray

NSArray *audienceTokens = @[@"Your Profile API (Audience) Token here"];
NSDictionary *keys = @{@"your_key": @"your_value"};
NSDictionary<TDRequestOptionsKey, id> *options = @{
    TDRequestOptionsTimeoutIntervalKey: [NSNumber numberWithInteger: 10],
    TDRequestOptionsCachePolicyKey: [NSNumber numberWithUnsignedInteger: NSURLRequestReloadIgnoringCacheData]
};
[[TreasureData sharedInstance] fetchUserSegments:audienceTokens
                                            keys:keys
                                         options:options
                               completionHandler:^(NSArray * _Nullable jsonResponse, NSError * _Nullable error) {
   NSLog(@"fetchUserSegments jsonResponse: %@", jsonResponse);
   NSLog(@"fetchUserSegments error: %@", error);
}];
```


## GDPR Compliance

The SDK provide some convenient methods to easily opt-out of tracking the device entirely without having to resort to many cluttered if-else statements:

```
// Opt-out of your own events
[[TreasureData sharedInstance] disableCustomEvent];
// Opt-out of TD generated events
[[TreasureData sharedInstance] disableAppLifecycleEvent];
[[TreasureData sharedInstance] disableInAppPurchaseEvent];
```

These can be opted back in by calling `enableCustomEvent` or `enableAppLifecycleEvent`. Note that these settings are saved persistently, so it survives across app launches. Generally these methods should be called when reflecting your user's choice, not on every time initializing the SDK. By default custom events are enabled and app lifecycles events are disabled. 

- Use `resetUniqId` to reset the identification of device on subsequent events. `td_uuid` will be randomized to another value and an extra event is captured with `{"td_ios_event":  "forget_device_id", "td_uuid": <old_uuid>}` to the `defaultTable`.

## tvOS

This SDK supports Apple tvOS version 12 and up. APIs and their behaviors are largely the same as being used in iOS application, except:

! In tvOS, cache storage is stored in cache directory which can be purged at any time. It is highly recommended to call upload events APIs as requently as possible to prevent loss of data.

## Supported OS versions

#### iOS

| iOS Version | v0.8.0             | v0.9.0             | v1.0.1             | v1.1.0             | v1.1.1             | v1.2.0 & v1.2.1    |
| :---------- | :----------------- | :----------------- | :----------------- | :----------------- | :----------------- | :----------------- |
| 18          | not tested         | not tested         | not tested         | not tested         | not tested         | :white_check_mark: |
| 17          | not tested         | not tested         | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| 16          | not tested         | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| 15          | not tested         | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| 14          | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| 13          | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | not tested         |
| 12          | :white_check_mark: | :white_check_mark: | :white_check_mark: | not tested         | not tested         | not tested         |
| 11          | :white_check_mark: | not tested         | not tested         | not tested         | not tested         | not tested         |
| 10          | :white_check_mark: | not tested         | not tested         | not tested         | not tested         | not tested         |
| 9           | :white_check_mark: | not tested         | not tested         | not tested         | not tested         | not tested         |
| 8           | :white_check_mark: | not tested         | not tested         | not tested         | not tested         | not tested         |
| 7           | not tested         | not tested         | not tested         | not tested         | not tested         | not tested         |

#### tvOS

| tvOS Version | v0.8.0             | v0.9.0             | v1.0.1             | v1.1.0             | v1.1.1             | v1.2.0 & v1.2.1    |
| :----------- | :----------------- | :----------------- | :----------------- | :----------------- | :----------------- | :----------------- |
| 12 and up    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
