TreasureData iOS SDK
===============

iOS SDK for [TreasureData](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into TreasureData easily. This library supports iOS 5 or later.

## Installation

[CocoaPods](http://cocoapods.org/) is needed to set up the SDK. If you've not installed it yet, install it at first.

```
$ gem install cocoapods
```

Next, add this line in your Podfile.

```
pod 'TreasureData-iOS-SDK', '= 0.1.6'
```

Finally, execute 'pod install'.

```
$ pod install
```

## Usage

### Import SDK header file

```
#import "TreasureData.h"
```

### Register your TreasureData API key

```
- (void)applicationDidBecomeActive:(UIApplication *)application {
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
Or, simply call `TreasureData#addEvent` instead of `TreasureData#addEventWithCallback`.

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
    UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{}];
    [[TreasureData sharedInstance] uploadEventsWithCallback:^() {
        [application endBackgroundTask:bgTask];
    }
            onError:^(NSString *code, NSString *msg) {
                [application endBackgroundTask:bgTask];
            }
     ];
}
```
Or, simply call `TreasureData#uploadEvents` instead of `TreasureData#uploadEventsWithCallback`.

```
    [[TreasureData sharedInstance] uploadEvents];

```

The sent events are going to be buffered for a few minutes before they get sent and imported into TreasureData storage.


### Start/End session

When you call `TreasureData#startSession()`, the SDK generates a session ID that's kept until `TreasureData#endSession()` is called. The session id is outputs as a column name "td_session_id". Also, `TreasureData#startSession()` and `TreasureData#endSession()` add an event that includes `{"td_session_event":"start" or "end"}`.

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
	
	UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{}];
	[[TreasureData sharedInstance] uploadEventsWithCallback:^() {
				[application endBackgroundTask:bgTask];
			}
			onError:^(NSString *code, NSString *msg) {
			    [application endBackgroundTask:bgTask];
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

You can detect if it's the first running or not easily using `TreasureData#isFirstRun()` and then clear the flag with `TreasureData#clearFirstRun()`.

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

`TreasureData#addEventWithCallback()` and `uploadEventsWithCallback()` call back `onError` block with `errorCode` argument. This argument is useful to know the cause type of the error. There are the following error codes.

- "init_error"
  - The initialization failed.
- "invalid_param"
  - The parameter passed to the API was invalid
- "invalid_event"
  - The event was invalid
- "data_conversion"
  - Failed to convert the data to/from JSON
- "storage_error"
  - Failed to read/write data in the storage
- "network_error"
  - Failed to communicate with the server due to network problem 
- "server_response"
  - The server returned an error response


## Additional Configuration

### Endpoint

The API endpoint (default: https://in.treasuredata.com) can be modified using the `setApiEndpoint` API after the client has been initialized using the `initializeWithApiKey` API. For example,

```
    [TreasureData initializeApiEndpoint:@"https://in.treasuredata.com"];
    [TreasureData initializeWithApiKey:@"your_api_key"];
```

### Encryption key

If you've set an encryption key via `initializeEncryptionKey`, our SDK saves the event data as encrypted when called `addEvent` or `addEventWithCallback`.  

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

UUID of the device will be added to each event automatically if you call `TreasureData#enableAutoAppendUniqId()`. This value won't change until the application is uninstalled.

```
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
		:
	[[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"dragged" }
												database:@"testdb" table:@"demotbl"];
```

It outputs the value as a column name `td_uuid`.


### Adding the device model information to each event automatically

Device model infromation will be added to each event automatically if you call `TreasureData#enableAutoAppendModelInformation()`.

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
