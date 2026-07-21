//
//  TDClient.swift
//  TreasureData
//
//  The HTTP sender for the event engine, owned by `SwiftEventEngine`: builds a
//  Treasure Data ingest request (TD auth, content types, gzip) and drives the
//  retry loop.
//

import Foundation
import GZIP
#if canImport(UIKit)
import UIKit
#endif
import CommonCrypto

final class TDClient {

    private static let sdkVersion = "2.0.0"

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

    init(apiKey: String, apiEndpoint: String) {
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
    }

    /// The on-disk buffer namespace derived from the api key; the engine reads
    /// it to scope its store. The "_td <sha256(apiKey)>" scheme is a legacy
    /// format preserved so upgrading apps reuse their existing buffer.
    var projectIdForBuffer: String { "_td \(TDClient.sha256Hash(apiKey))" }

    private static func sha256Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Build the TD ingest request for one `database`.`table` and send it,
    /// driving the retry loop.
    func sendEvents(_ data: Data,
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
