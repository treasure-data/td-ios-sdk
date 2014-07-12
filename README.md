TreasureData iOS SDK
===============

iOS SDK for [TreasureData](http://www.treasuredata.com/). With this SDK, you can import the events on your applications into TreasureData easily.

## Installation

[CocoaPods](http://cocoapods.org/) is needed to set up the SDK. If you've not installed it yet, install it at first.

```
$ gem install cocoapods
```

Next, add this line in your Podfile.

```
pod 'TreasureData-iOS-SDK', '= 0.1.0'
```

Finally, execute 'pod install'.
```
$ pod install
```

## Usage

### Register Your TreasureData API Key

```objc
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

```objc
- (IBAction)clickButton:(id)sender {
    [[TreasureData sharedInstance] event:@{
                                     @"name": @"foo bar",
                                     @"age": @42,
                                     @"comment": @"hello world"
                                   }
                                database:@"database_a"
                                   table:@"table_b"];
}
```

Specify the database and table to which you want to import the events.

### Upload Events to TreasureData

```objc
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[TreasureData sharedInstance] uploadWithBlock:^(void) {
        NSLog(@"Uploaded.");
    }];
}
```

The events are going to be buffered for a few minutes before they get sent and imported into TreasureData storage.

## Additional Configuration

### Endpoint

The API endpoint (default: https://in.treasuredata.com/ios/v3) can be modified using the `setApiEndpoint` API after the client has been initialized using the `initializeWithApiKey` API.



