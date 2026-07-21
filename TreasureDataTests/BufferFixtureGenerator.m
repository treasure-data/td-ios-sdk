//
//  BufferFixtureGenerator.m
//  TreasureDataTests
//
//  ONE-TIME, ON-DEMAND generator for the on-disk Buffer compatibility fixtures
//  used by the Buffer format gate test. It is NOT part of the
//  normal suite: every method is prefixed `generate_` (not `test`) so XCTest
//  does not auto-run it. Run a method explicitly to (re)produce a fixture:
//
//      xcodebuild test ... -only-testing:TreasureDataTests/BufferFixtureGenerator/generate_plainFixture
//
//  Each method drives the CURRENT (KeenClient) engine to write real bytes to
//  `Library/keenEvents.sqlite`, then copies that file into the repo at
//  Fixtures/. Commit the copied files. Once KeenClient is gone the fixtures
//  remain the oracle — the Swift engine must read exactly these bytes.
//
//  ponytail: on-demand generator, not a test. Regenerate only if the v1 write
//  format legitimately changes (it must not, for upgraders).
//

#import <XCTest/XCTest.h>
@import KeenClientTD;
#import "TDConstants.h"
#import "TreasureData-Swift.h"

// Where committed fixtures live, relative to this source file. __FILE__ is the
// absolute path of this file at compile time, so we can find the repo without
// hardcoding a machine path.
static NSString *fixturesDir(void) {
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    NSString *testsDir = [thisFile stringByDeletingLastPathComponent];
    return [[testsDir stringByAppendingPathComponent:@"Fixtures"] stringByStandardizingPath];
}

// The path KIOEventStore writes to. Mirrors -getDatabaseFilePath in
// KIOEventStore.m (Library on iOS, Caches on tvOS).
static NSString *liveDBPath(void) {
#if TARGET_OS_TV
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
#else
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
#endif
    return [base stringByAppendingPathComponent:@"keenEvents.sqlite"];
}

// The canonical event set every fixture contains. Kept small and explicit so
// the gate test can assert exact contents. Two collections, mixed value types.
static NSArray<NSDictionary *> *fixtureEvents(void) {
    return @[
        @{ @"db_fix.tbl_a": @{ @"name": @"foobar", @"n": @1 } },
        @{ @"db_fix.tbl_a": @{ @"name": @"second", @"n": @2 } },
        @{ @"db_fix.tbl_b": @{ @"name": @"other",  @"flag": @YES } },
    ];
}

@interface BufferFixtureGenerator : XCTestCase
@end

@implementation BufferFixtureGenerator

// Delete the live DB so each generation starts from an empty buffer.
- (void)wipeLiveDB {
    [[KeenClient getEventStore] deleteAllEvents];
    // deleteAllEvents is async on the db queue; also remove the file itself so a
    // stale schema/rows can't leak into the fixture.
    [[NSFileManager defaultManager] removeItemAtPath:liveDBPath() error:nil];
}

- (TreasureData *)freshTD {
    TreasureData *td = [[TreasureData alloc] initWithApiKey:@"fixture_apikey"
                                                apiEndpoint:@"http://localhost"];
    [td setDefaultDatabase:@"db_fix"];
    [td enableCustomEvent];
    return td;
}

// Write the canonical events, wait for the serial db queue to flush, then copy
// the live DB into Fixtures/<name>. Prints the destination so the run log tells
// you exactly what to commit.
- (void)writeEventsThenCopyTo:(NSString *)fixtureName {
    TreasureData *td = [self freshTD];
    for (NSDictionary *ev in fixtureEvents()) {
        NSString *coll = ev.allKeys.firstObject;
        NSArray *parts = [coll componentsSeparatedByString:@"."];
        [td addEvent:ev[coll] database:parts[0] table:parts[1]];
    }

    // addEvent writes synchronously (dispatch_sync on the db queue), but bounce
    // through the queue once more to be certain everything is committed.
    XCTestExpectation *flushed = [self expectationWithDescription:@"db flushed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [flushed fulfill]; });
    [self waitForExpectations:@[flushed] timeout:5];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:fixturesDir() withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *dest = [fixturesDir() stringByAppendingPathComponent:fixtureName];
    [fm removeItemAtPath:dest error:nil];

    NSError *copyErr = nil;
    BOOL ok = [fm copyItemAtPath:liveDBPath() toPath:dest error:&copyErr];
    XCTAssertTrue(ok, @"failed to copy fixture: %@", copyErr);

    NSLog(@"[fixture] wrote %lu events -> %@", (unsigned long)fixtureEvents().count, dest);
    XCTAssertTrue([fm fileExistsAtPath:dest]);
}

- (void)generate_plainFixture {
    [TreasureData initializeEncryptionKey:nil];
    [self wipeLiveDB];
    [self writeEventsThenCopyTo:@"keenEvents-v1-plain.sqlite"];
}

- (void)generate_encryptedFixture {
    // Key length matters: KIOEventStore uses the raw UTF-8 bytes truncated to
    // 16 (AES-128). This exact key is baked into the gate test.
    [TreasureData initializeEncryptionKey:@"0123456789abcdef"];
    [self wipeLiveDB];
    [self writeEventsThenCopyTo:@"keenEvents-v1-encrypted.sqlite"];
    // Leave global key state clean for anything running afterward.
    [TreasureData initializeEncryptionKey:nil];
}

@end
