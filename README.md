TreasureData iOS SDK
===============

iOS SDK for [TreasureData](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into TreasureData easily. This library supports iOS 5 or later.

## Installation

There are several ways to install the library.

### CocoaPods

[CocoaPods](http://cocoapods.org/) is needed to set up the SDK. If you've not installed it yet, install it at first.

```
$ gem install cocoapods
```

Next, add this line in your Podfile.

```
pod 'TreasureData-iOS-SDK', '= 0.1.8'
```

Finally, execute 'pod install'.

```
$ pod install
```

### Framework

Download [TreasureData.framework](http://cdn.treasuredata.com/sdk/ios/0.1.8/TreasureData.framework.zip) and add it and `libz` library into your project.

### Static libraries and header files

Download [Static libraries and header files](http://cdn.treasuredata.com/sdk/ios/0.1.8/TreasureData.zip) and add it and `libz` library into your project.


## Usage

### Import SDK header file

```
#import "TreasureData.h"
```

When you install the library as a framework, use the following statement.

```
#import <TreasureData/TreasureData.h>
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

### Add events to local buffer

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
}
```
Or, simply call `addEvent` method instead of `addEventWithCallback`.

```
    [[TreasureData sharedInstance] addEvent:@{
                       @"name": @"boo bar",
                       @"age": @42,
                       @"comment": @"hello world"
                   }
                   database:@"testdb"
                      table:@"demotbl"];
```


Specify the database and table to which you want to import the events.

### Upload buffered events to TreasureData

```
- (void)applicationDidEnterBackground:(UIApplication *)application {
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
	];
}
```
Or, simply call `uploadEvents` method instead of `uploadEventsWithCallback`.

```
    [[TreasureData sharedInstance] uploadEvents];

```

The sent events are going to be buffered for a few minutes before they get sent and imported into TreasureData storage.


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
                                      [[TreasureData sharedInstance] clearFitstRun];
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

The API endpoint (default: https://in.treasuredata.com) can be modified using `initializeApiEndpoint` class method. For example,

```
    [TreasureData initializeApiEndpoint:@"https://in.treasuredata.com"];
    [TreasureData initializeWithApiKey:@"your_api_key"];
```

### Encryption key

If you've set an encryption key via `initializeEncryptionKey` class method, our SDK saves the events data as encrypted when called `addEvent` or `addEventWithCallback` methods.

```
    [TreasureData initializeEncryptionKey:@"hello world"];
        :
    [[TreasureData sharedInstance] addEventWithCallback: ....];
```

### Default database

```
    [[TreasureData sharedInstance] setDefaultDatabase:@"testdb"];
		:
	[[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"clicked" } table:@"demotbl"]
```	

### Adding UUID of the device to each event automatically

UUID of the device will be added to each event automatically if you call `enableAutoAppendUniqId`. This value won't change until the application is uninstalled.

```
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
		:
	[[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"dragged" }
												database:@"testdb" table:@"demotbl"];
```

It outputs the value as a column name `td_uuid`.


### Adding the device model information to each event automatically

Device model infromation will be added to each event automatically if you call `enableAutoAppendModelInformation`.

```
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];
		:
	[[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"dragged" }
												database:@"testdb" table:@"demotbl"];
```

It outputs the following column names and values:

- `td_device` : UIDevice.model
- `td_model` : UIDevice.model
- `td_os_ver` : UIDevice.model.systemVersion
- `td_os_type` : "iOS"

### Enable/Disable debug log

```
	[TreasureData enableLogging];
```

```
	[TreasureData disableLogging];
```
