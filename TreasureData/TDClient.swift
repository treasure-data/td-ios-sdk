//
//  TDClient.swift
//  TreasureData
//
//  Swift port of the Objective-C `TDClient`. A KeenClient subclass that reuses
//  KeenClient's event buffer + upload orchestration but overrides the private
//  `sendEvents:database:table:completionHandler:` hook to send requests to the
//  Treasure Data endpoint (TD auth, content types, gzip, retry).
//
//  This subclass is required because KeenClient invokes `[self sendEvents:...]`
//  during upload; composition alone can't intercept it. It is internal to the
//  engine and never exposed in the public API — replacing the KeenClient
//  dependency wholesale is deferred to a later phase.
//

import Foundation
import KeenClientTD
import GZIP
#if canImport(UIKit)
import UIKit
#endif
import CommonCrypto

final class TDClient: KeenClient {

    private static let sdkVersion = "1.3.0"

    var apiKey: String = ""
    var apiEndpoint: String = ""

    var isTrackingIP: Bool = false
    var isEventCompressionEnabled: Bool = false

    var retryEnabled: Bool = true
    // Wait before next retry = intervalCoefficient * intervalBase ^ retryCount.
    var retryIntervalCoefficient: Int = 4
    var retryIntervalBase: Int = 2
    var retryCount: Int = 5

    /// Injectable for testing; defaults to the shared session.
    var uploadSession: URLSession = .shared

    // A convenience initializer delegating to KeenClient's own
    // `initWithProjectId:andWriteKey:andReadKey:`. All stored properties above
    // have defaults, so TDClient inherits KeenClient's designated `init`
    // rather than overriding it — this avoids the re-entrant init trap that
    // arises because `initWithProjectId:` internally calls `[self init]`.
    convenience init(apiKey: String, apiEndpoint: String) {
        // KeenClient uses the project id to namespace its on-disk buffer; keep the
        // exact "_td <sha256(apiKey)>" scheme so upgrading apps reuse their buffer.
        let projectId = "_td \(TDClient.sha256Hash(apiKey))"
        self.init(projectId: projectId, andWriteKey: "dummy_write_key", andReadKey: "dummy_read_key")
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
        self.globalPropertiesBlock = { _ in
            return ["uuid": UUID().uuidString]
        }
    }

    private static func sha256Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // Overrides KeenClient's private `sendEvents:...` (declared to Swift via
    // KeenClient+TDOverride.h). Builds the TD request and drives the retry loop.
    override func sendEvents(_ data: Data,
                             database: String,
                             table: String,
                             completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let urlString = "\(apiEndpoint)/\(database)/\(table)"
        guard let url = URL(string: urlString) else {
            completionHandler(nil, nil, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("TD1 \(apiKey)", forHTTPHeaderField: "Authorization")
        let contentType = isTrackingIP
            ? "application/vnd.treasuredata.v1.mobile+json"
            : "application/vnd.treasuredata.v1+json"
        // Match the ObjC: Content-Type is set twice (json then the TD vnd type).
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(contentType, forHTTPHeaderField: "Accept")
        let systemName: String
        let systemVersion: String
        #if canImport(UIKit)
        systemName = UIDevice.current.systemName
        systemVersion = UIDevice.current.systemVersion
        #else
        systemName = "iOS"
        systemVersion = ""
        #endif
        request.setValue("TD-iOS-SDK/\(TDClient.sdkVersion) (\(systemName) \(systemVersion))",
                         forHTTPHeaderField: "User-Agent")

        if isEventCompressionEnabled {
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            request.httpBody = (data as NSData).gzipped()
        } else {
            request.httpBody = data
        }

        sendHTTPRequest(request, retryCounter: 0, completionHandler: completionHandler)
    }

    private func sendHTTPRequest(_ request: URLRequest,
                                 retryCounter: Int,
                                 completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = uploadSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if data != nil {
                completionHandler(data, response, error)
            } else {
                if !self.retryEnabled || retryCounter >= self.retryCount - 1 {
                    // Give up retry.
                    completionHandler(data, response, error)
                } else {
                    let wait = Double(self.retryIntervalCoefficient) * pow(Double(self.retryIntervalBase), Double(retryCounter))
                    Thread.sleep(forTimeInterval: wait)
                    self.sendHTTPRequest(request, retryCounter: retryCounter + 1, completionHandler: completionHandler)
                }
            }
        }
        task.resume()
    }
}
