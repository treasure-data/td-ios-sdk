//
//  BufferContractTest.m
//  TreasureDataTests
//
//  THE BUFFER FORMAT GATE. Proves the engine can read the on-disk
//  Buffer format that the v1 (KeenClient) engine wrote: it copies a committed
//  fixture DB (produced by BufferFixtureGenerator against the v1 engine) into
//  the live `keenEvents.sqlite` location, then drains it through the public
//  upload path and asserts the exact events come back — plain and encrypted.
//
//  Against today's engine this passes trivially (same engine wrote the fixture).
//  Its value is that it must KEEP passing after KeenClient is replaced by the
//  Swift engine. If the Swift store's SQLite schema, AES, base64, or projectId
//  scheme drift by even a byte, this goes red. Do not weaken it to make a port
//  compile — a port that fails this loses upgraders' buffered events.
//
//  Ordering constraint: the fixture must be copied into place BEFORE the shared
//  KIOEventStore opens the DB (it opens in its own -init, lazily, on the first
//  TreasureData instantiation). So the copy happens in -setUp before any
//  TreasureData is created, and we can only reliably control that if this is the
//  first store use in the process. Each test also uses a distinct projectId
//  (apiKey) matching the fixture, so a store opened earlier still reads our rows.
//

#import <XCTest/XCTest.h>
@import KeenClientTD;
#import "TDConstants.h"
#import "TreasureData-Swift.h"

// The shared KIOEventStore is a process-global singleton that opens
// keenEvents.sqlite once and keeps the handle. To drain a freshly-installed
// fixture, we must close that handle so the next access reopens the new file.
// closeDB is exposed via KeenClient's private-methods header.
@interface KIOEventStore (ContractTest)
- (void)closeDB;
- (void)releaseStatements;
@end

// The apiKey the fixtures were generated with (BufferFixtureGenerator uses
// "fixture_apikey"); the store namespaces rows by projectId = _td <sha256(key)>,
// so the draining TreasureData must use the same key to see the fixture's rows.
static NSString *const kFixtureApiKey = @"fixture_apikey";
static NSString *const kFixtureEncryptionKey = @"0123456789abcdef";

// Mirrors MySession in TreasureDataTests.m: captures upload requests and returns
// a canned 200 so the drain path deletes events and reports success.
@interface ContractSessionTask : NSURLSessionDataTask
@end
@implementation ContractSessionTask
- (void)resume {}
@end

@interface ContractSession : NSURLSession
@property NSMutableArray<NSURLRequest *> *requests;
@property NSData *responseBody;
@property NSURLResponse *response;
@end
@implementation ContractSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    @synchronized (self) {
        if (!self.requests) { self.requests = [NSMutableArray new]; }
        [self.requests addObject:request];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(self.responseBody, self.response, nil);
    });
    return (NSURLSessionDataTask *)[ContractSessionTask new];
}
@end

@interface BufferContractTest : XCTestCase
@end

@implementation BufferContractTest

// Absolute path of a committed fixture.
- (NSString *)fixturePath:(NSString *)name {
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    NSString *dir = [[thisFile stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Fixtures"];
    return [[dir stringByAppendingPathComponent:name] stringByStandardizingPath];
}

// The live DB path KIOEventStore uses (Library on iOS, Caches on tvOS).
- (NSString *)liveDBPath {
#if TARGET_OS_TV
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
#else
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
#endif
    return [base stringByAppendingPathComponent:@"keenEvents.sqlite"];
}

// Copy a fixture over the live DB, then close the shared store's open handle so
// the next access reopens the freshly-installed file. Without the close, the
// store keeps reading whichever DB it opened first in this process.
- (void)installFixture:(NSString *)name {
    KIOEventStore *store = [KeenClient getEventStore];
    if (store) {
        [store releaseStatements];
        [store closeDB];
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *live = [self liveDBPath];
    [fm removeItemAtPath:live error:nil];
    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:[self fixturePath:name] toPath:live error:&err];
    XCTAssertTrue(ok, @"failed to install fixture %@: %@", name, err);
}

// Drain the buffer through the public upload path and return the union of all
// events across every uploaded request, keyed by "database.table".
- (NSDictionary<NSString *, NSArray *> *)drain:(TreasureData *)td session:(ContractSession *)session {
    NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost/x"]
                                                       statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    session.response = ok;
    // Upload response body: report success for each collection so events delete.
    session.responseBody = [NSJSONSerialization dataWithJSONObject:@{@"receipts": @[@{@"success": @YES}, @{@"success": @YES}]}
                                                           options:0 error:nil];

    __block BOOL done = NO;
    [td uploadEventsWithCallback:^{ done = YES; }
                         onError:^(NSString *c, NSString *m) {
        XCTFail(@"drain failed: %@ / %@", c, m);
        done = YES;
    }];
    // Pump the run loop until the async upload callback fires.
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    XCTAssertTrue(done, @"upload did not complete");

    NSMutableDictionary<NSString *, NSMutableArray *> *out = [NSMutableDictionary dictionary];
    for (NSURLRequest *req in session.requests) {
        NSString *url = req.URL.absoluteString;
        NSString *table = url.lastPathComponent;
        NSString *db = [url stringByDeletingLastPathComponent].lastPathComponent;
        NSString *coll = [NSString stringWithFormat:@"%@.%@", db, table];
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:req.HTTPBody options:0 error:nil];
        NSArray *events = body[@"events"];
        if (events) {
            if (!out[coll]) { out[coll] = [NSMutableArray array]; }
            [out[coll] addObjectsFromArray:events];
        }
    }
    return out;
}

- (TreasureData *)makeTD:(ContractSession *)session {
    // Compression is a process-global flag; a prior test may have left it on,
    // which would gzip the upload body and break our JSON assertions. Force off.
    [TreasureData disableEventCompression];
    TreasureData *td = [[TreasureData alloc] initWithApiKey:kFixtureApiKey apiEndpoint:@"http://localhost"];
    td.session = session;
    [td setDefaultDatabase:@"db_fix"];
    [td enableCustomEvent];
    return td;
}

// Assert the fixture's 3 canonical events came back intact, regardless of order.
- (void)assertFixtureEvents:(NSDictionary<NSString *, NSArray *> *)drained {
    NSArray *tblA = drained[@"db_fix.tbl_a"];
    NSArray *tblB = drained[@"db_fix.tbl_b"];
    XCTAssertEqual(tblA.count, 2u, @"tbl_a should have 2 events");
    XCTAssertEqual(tblB.count, 1u, @"tbl_b should have 1 event");

    NSSet *namesA = [NSSet setWithArray:[tblA valueForKey:@"name"]];
    NSSet *expectedNamesA = [NSSet setWithArray:@[@"foobar", @"second"]];
    XCTAssertEqualObjects(namesA, expectedNamesA, @"tbl_a names mismatch");
    XCTAssertEqualObjects(tblB.firstObject[@"name"], @"other");

    // Value types survive the round trip (n is numeric, flag is boolean).
    for (NSDictionary *e in tblA) {
        XCTAssertTrue([e[@"n"] isKindOfClass:[NSNumber class]], @"n should be a number");
    }
    XCTAssertTrue([tblB.firstObject[@"flag"] isKindOfClass:[NSNumber class]], @"flag should be a number/bool");
}

#pragma mark - The gate

- (void)testReadsV1PlainBuffer {
    [TreasureData initializeEncryptionKey:nil];
    [self installFixture:@"keenEvents-v1-plain.sqlite"];

    ContractSession *session = [ContractSession new];
    TreasureData *td = [self makeTD:session];
    [self assertFixtureEvents:[self drain:td session:session]];
}

- (void)testReadsV1EncryptedBuffer {
    // Key must be set before the store reads/decrypts rows.
    [TreasureData initializeEncryptionKey:kFixtureEncryptionKey];
    [self installFixture:@"keenEvents-v1-encrypted.sqlite"];

    ContractSession *session = [ContractSession new];
    TreasureData *td = [self makeTD:session];
    [self assertFixtureEvents:[self drain:td session:session]];

    [TreasureData initializeEncryptionKey:nil];
}

@end
