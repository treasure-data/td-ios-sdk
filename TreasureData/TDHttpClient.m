//
//  TDHttpClient.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/29/14.
//  Copyright (c) 2014 Mitsunori Komatsu. All rights reserved.
//

#import "TDHttpClient.h"

@interface TDHttpClient ()
@property(nonatomic, strong) NSURLConnection *conn;
@property(nonatomic, strong) NSData *responseData;
@property(nonatomic, strong) NSURLResponse *response;
@property(nonatomic, strong) NSError *error;
@property BOOL isFinished;
@end

@implementation TDHttpClient
- (NSData *)sendRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    self.conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!self.conn) {
        NSLog(@"Connection wasn't created");
        return nil;
    }

    int count = 20;
    self.response = nil;
    self.responseData = nil;
    self.error = nil;
    self.isFinished = false;
    while (!self.isFinished && count-- > 0) {
        NSLog(@"Waiting...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
    NSLog(@"error=%@", self.error);
    NSLog(@"responseData=%@", [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding]);
    NSLog(@"response=%@", self.response);

    *response = self.response;
    *error = self.error;
    return self.responseData;
}

- (BOOL)shouldTrustProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    NSLog(@"shouldTrustProtectionSpace");
    // Load up the bundled certificate.
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Resources" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *certPath = [bundle pathForResource:@"gd_bundle" ofType:@"der"];
    NSData *certData = [[NSData alloc] initWithContentsOfFile:certPath];
    CFDataRef certDataRef = (__bridge_retained CFDataRef)certData;
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, certDataRef);
    
    // Establish a chain of trust anchored on our bundled certificate.
    CFArrayRef certArrayRef = CFArrayCreate(NULL, (void *)&cert, 1, NULL);
    SecTrustRef serverTrust = protectionSpace.serverTrust;
    SecTrustSetAnchorCertificates(serverTrust, certArrayRef);
    
    // Verify that trust.
    SecTrustResultType trustResult;
    SecTrustEvaluate(serverTrust, &trustResult);
    
    // Clean up.
    CFRelease(certArrayRef);
    CFRelease(cert);
    CFRelease(certDataRef);
    
	// Did our custom trust chain evaluate successfully?
    return trustResult == kSecTrustResultUnspecified;
}

#pragma mark NSURLConnection Delegate Methods

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    NSLog(@"canAuthenticateAgainstProtectionSpace");
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSLog(@"didReceiveAuthenticationChallenge");
    
    if ([self shouldTrustProtectionSpace:challenge.protectionSpace]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.responseData = data;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = response;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.error = error;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.isFinished = true;
}
@end
