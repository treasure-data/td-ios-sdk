TreasureData iOS SDK
===============

iOS SDK for [TreasureData](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into TreasureData easily. This library supports iOS 5 or later.

## Installation

[CocoaPods](http://cocoapods.org/) is needed to set up the SDK. If you've not installed it yet, install it at first.

```
$ gem install cocoapods
```

Then, add our Pods to use some components.

```
$ pod repo add td https://github.com/treasure-data/PodSpecs.git
```

Next, add this line in your Podfile.

```
pod 'TreasureData-iOS-SDK', '= 0.1.4'
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

### Register Your TreasureData API Key

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

### Add Events

```
- (IBAction)clickButton:(id)sender {
    [[TreasureData sharedInstance] addEventWithCallback:@{
                                       @"name": @"boo bar",
                                       @"age": @42,
                                       @"comment": @"hello world"
                                   }
                                   database:@"database_a"
                                      table:@"table_b"
                                  onSuccess:^(){
                                      NSLog(@"addEvent: success");
                                  }
                                    onError:^(NSString* errorCode, NSString* message) {
                                        NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
                                    }];
}
```
Or, simply

```
    [[TreasureData sharedInstance] addEvent:@{
                                       @"name": @"boo bar",
                                       @"age": @42,
                                       @"comment": @"hello world"
                                   }
                                   database:@"database_a"
                                      table:@"table_b"];
```


Specify the database and table to which you want to import the events.

### Upload Events to TreasureData

```
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[TreasureData sharedInstance] uploadEventsWithCallback:^(){
                                       NSLog(@"uploadEvents: success");
                                   }
                                   onError:^(NSString* errorCode, NSString* message) {
                                       NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
                                   }];
}
```
Or, simply

```
    [[TreasureData sharedInstance] uploadEvents];

```


The events are going to be buffered for a few minutes before they get sent and imported into TreasureData storage.

## About Error Code

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

## Use Cases

### Collect The First Run Event (Installation Event)

You can collect the first run event of your application like this. Probably, this event can be used as an installation event.

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TreasureData initializeWithApiKey:@"your_api_key"];

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        [[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"installed" }
						 database:@"database_a"
						    table:@"table_b"
						onSuccess:^(){
						    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
						    [[NSUserDefaults standardUserDefaults] synchronize];
						    [[TreasureData sharedInstance] uploadEvents];
						}
						  onError:^(NSString* errorCode, NSString* message) {
						      NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
						  }];
    }
    
    return YES;
}
```
