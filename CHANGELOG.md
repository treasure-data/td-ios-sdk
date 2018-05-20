# Change Log

## Version 0.1.27
_2018-05-21

* Support GDPR compliancy

- Remove `enableAutoTrackToDatabase:table`.
- Added `enable/disableCustomEvent` and `enable/disableAppLifecycleEvents`.
- Added `resetUniqId`.

* Others

- Added `defaultTable` property as the target table for app lifecycles and audit events.

## Version 0.1.26
_2018-04-05_

- Eliminate some XCode 9 inspection warnings.

## Version 0.1.25
_2018-03-26_

* Add automated event tracking functionality

## Version 0.1.24
_2017-04-20_

* Call `onSuccess` of `uploadEventsWithCallback` even when buffered data is empty

## Version 0.1.23
_2017-03-13_

* Add an instance method `getSessionId` to TreasureData class

## Version 0.1.22
_2017-03-10_

* Add a class method `getSessionId` to TreasureData class

## Version 0.1.21
_2016-11-11_

* Fix "Include of non-modular header inside framework module" error in TreasureDataExampleSwift

## Version 0.1.20
_2016-10-14_

* Fix a rare crash that might occur when the first calling `createTable` fails in KeenClientTD

## Version 0.1.19
_2016-08-02_

* Add enableAutoAppendRecordUUID method to TreasureData
* Make enableServerSideUploadTimestamp method of TreasureData accept a custom column name

## Version 0.1.18
_2016-07-13_

* Set minimum iOS version explicitly

## Version 0.1.17
_2016-06-24_

* Support application based global session to be able to handle a short screen transition from/to other screen as the same session
* Add enableAutoAppendAppInformation and enableAutoAppendLocaleInformation functions to TreasureData

## Version 0.1.16
_2016-05-19_

* Fix bug TreasureData#uploadEventsWithCallback doesn't call callbacks

## Version 0.1.15
_2016-05-16_

* Support tvOS
* Remove deprecated API call

## Version 0.1.14
_2016-04-18_

* Fix possible race condition in accessing SQLite

## Version 0.1.13
_2016-02-29_

* Fix warnings that version 0.1.12 failed to fix

## Version 0.1.12
_2016-02-22_

* Fix a lot of warnings when building with `DWARF with dSYM`

## Version 0.1.11
_2016-02-17_

* Fix crash that occurs when handling invalid database or table name

## Version 0.1.10
_2016-01-29_

* Fix crash that happens when Data Protection is enabled and API is called 10 seconds after iOS is locked

## Version 0.1.9
_2016-01-07_

* Enable server side upload timestamp

## Version 0.1.8

* Fix a lot of warnings in amalgamation sqlite3.c
* Improve the retry interval of HTTP request

## Version 0.1.7

* Support Framework

## Version 0.1.6

* Append device model infromation and persistent UUID which is generated at the first launch to each event if it's turned on
* Add session id
* Add first run flag so that the application detects the first launch
* Retry uploading
* Remove gd_bundle.crt from Objective-C source file

## Version 0.1.5

* Fix TreasureData.addEvent

## Version 0.1.4

* Fix HTTP connectivity issue to an endpoint other than the default one

## Version 0.1.3

* Support iOS 5

## Version 0.1.2

* Fix some bugs related to encryption

## Version 0.1.1

* Implement gd_bundle.crt into the source file
* Enable to change API endpoint with TreasureData#initializeApiEndpoint()
* Improve error handling with TreasureData#addEventWithCallback() and TreasureData#uploadEventsWithCallback()
* Enable the encryption of bufferred event data with TreasureData.initializeEncryptionKey()
* Buffer event data in Sqlite3 instead of files

## Version 0.1.0

* Added 'Security' framework to TreasureData-iOS-SDK.podspec
* Updated KeenClient version up to 3.2.8

