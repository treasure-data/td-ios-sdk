//
//  NSURLSessionStub.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/24/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

final class NSURLSessionStub: NSURLSession {
    typealias CompletionResponse = (NSData?, NSURLResponse?, NSError?)
    var completionResponse: CompletionResponse?
    typealias RequestValidation = (NSURLRequest) -> Void
    var requestValidation: RequestValidation?
    private let dataTask = NSURLSessionDataTaskStub()
    
    override func dataTaskWithRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDataTask {
        self.requestValidation?(request)
        self.dataTask.completionResponse = self.completionResponse
        self.dataTask.completionHanlder  = completionHandler
        return self.dataTask
    }
    
    final class NSURLSessionDataTaskStub: NSURLSessionDataTask {
        typealias CompletionHandler = CompletionResponse -> Void
        var completionHanlder: CompletionHandler?
        
        var completionResponse: CompletionResponse?
        
        override func resume() {
            let data     = self.completionResponse?.0
            let response = self.completionResponse?.1
            let error    = self.completionResponse?.2
            self.completionHanlder?(data, response, error)
        }
    }
}
