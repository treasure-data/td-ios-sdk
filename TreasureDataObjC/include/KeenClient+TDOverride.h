//
//  KeenClient+TDOverride.h
//  TreasureData
//
//  KeenClient declares `sendEvents:database:table:completionHandler:` only in its
//  private .m interface, so Swift cannot see (and therefore cannot override) it.
//  The engine's KeenClient subclass must override this method to redirect uploads
//  to the Treasure Data endpoint. Re-declaring the selector here (imported via the
//  bridging header) makes it visible to Swift so the override compiles; the actual
//  implementation still lives in KeenClient.m / the Swift subclass.
//

@import KeenClientTD;

@interface KeenClient (TDOverride)

- (void)sendEvents:(nonnull NSData *)data
          database:(nonnull NSString *)database
             table:(nonnull NSString *)table
 completionHandler:(nonnull void (^)(NSData * _Nullable data,
                                     NSURLResponse * _Nullable response,
                                     NSError * _Nullable error))completionHandler;

@end
