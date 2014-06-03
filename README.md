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
pod 'TreasureData-iOS-SDK'
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

To create a new write-only user for the application and use the API key of the user here is recommended. With multi-user feature of TreasureData, you can add a new user easily.

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

The sent events is going to be buffered for a few minutes before they get imported into TreasureData storage.

