//
//  TDAPI.swift
//  TreasureDataTests
//
//  Created by huylenq on 1/27/19.
//  Copyright © 2019 Treasure Data. All rights reserved.
//

import Foundation

/*!
 * Naive and adhoc API client to TreasureData, only serve for test cases verifying purpose
 */
class TDAPI {
    let apiKey: String
    let endpoint: String
    let debug: Bool

    enum TDAPIError: Error {
        case jobError(String)
        case queryError(String)
        case operationError(String)
        case timeoutError(String)
    }

    init(endpoint: String = "https://api-development.treasuredata.com", apiKey: String, debug: Bool = false) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.debug = debug
    }

    func waitForJob(jobID: String) throws {
        var jobStatus: String?
        jobStatus = getJobStatus(jobID: jobID)
        while jobStatus == nil || jobStatus == "running" || jobStatus == "queued" {
            Thread.sleep(forTimeInterval: 5)
            jobStatus = getJobStatus(jobID: jobID)
        }
        if jobStatus != "success" {
            throw TDAPIError.jobError("Job \(jobID) was failed for some reason!")
        }
    }

    func getJobStatus(jobID: String) -> String {
        let (_, job) = getAsJSON("v3/job/status/\(jobID)")
        return job!["status"] as! String
    }

    func query(_ query: String, database: String) throws -> [[Any]] {
        let (_, queryResp) = post(
                "v3/job/issue/hive/\(database)",
                params: ["query": query])
        let jobID = queryResp!["job_id"] as! String
        do {
            try waitForJob(jobID: jobID)
        } catch {
            throw TDAPIError.queryError("Failed to execute query '\(query)'")
        }
        let (_, jobResultData) = get("v3/job/result/\(jobID)")
        return String(data: jobResultData!, encoding: .utf8)!
                .components(separatedBy: .newlines)
                .filter {
                    $0.count > 0
                }
                .map {
                    (line: String) -> Any in
                    return line.components(separatedBy: ",")
                } as! [[Any]]
    }

    /*!
     * Retry query until succeed
     *
     * - Parameter timeout: timeout in seconds, default is 15 minutes
     */
    func stubbornQuery(_ query: String, database: String, timeout: TimeInterval = 15 * 60) throws -> [[Any]] {
        let started = Date()

        func doRetry(_ query: String, database: String) throws -> [[Any]] {
            if abs(started.timeIntervalSinceNow) > timeout {
                throw TDAPIError.timeoutError("Took too long (more than \(timeout) seconds) to execute query '\(query)'")
            }
            do {
                return try self.query(query, database: database)
            } catch TDAPIError.queryError {
                return try doRetry(query, database: database)
            } catch {
                fatalError()
            }
        }

        return try doRetry(query, database: database)
    }
    
    /*!
     * Return a list of table name
     */
    public func listTables(database: String) -> [String] {
        let (_, data) = getAsJSON("v3/table/list/\(database)")
        return (data!["tables"] as! [[String: Any]]).map { (table: [String: Any]) in table["name"] as! String }
    }
    
    public func deleteTable(database: String, table: String) throws {
        let (status, _) = post("v3/table/delete/\(database)/\(table)")
        if (status != 200) {
            throw TDAPIError.operationError("Unable to delete the table \(database).\(table)")
        }
    }
    
    public func isDatabaseExist(_ database: String) throws -> Bool {
        // Simply prope for table lists, consider database is unexist if the request fails
        let (status, _) = get("v3/table/list/\(database)")
        switch status {
        case 200: return true
        case 404: return false
        default:
            throw TDAPIError.operationError("Unrecognized status code repsonse from 'v3/table/list/\(database)")
        }
    }

    private func getAsJSON(_ path: String) -> (Int, [String: Any]?) {
        let (status, data) = get(path)
        return (status, try! JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any])
    }
    
    /*!
     * Synchronously do a GET request
     */
    private func get(_ path: String, headers: [String: String] = [:]) -> (Int, Data?) {
        var req: URLRequest = URLRequest(url: URL(string: "\(endpoint)/\(path)")!)
        req.httpMethod = "GET"
        req.setValue("TD1 \(apiKey)", forHTTPHeaderField: "Authorization")

        var status: Int?
        var respData: Data?

        headers.forEach {
            req.setValue($1, forHTTPHeaderField: $0)
        }

        let semaphore = DispatchSemaphore(value: 0)

        if debug {
            print("[TDAPI] Request: \(req.httpMethod!) \(req.url!.absoluteString)")
        }

        let dataTask: URLSessionDataTask = URLSession.shared.dataTask(with: req) {
            data, response, error in
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse;
            status = httpResponse.statusCode
            if (httpResponse.statusCode == 200) {
                print("[TDAPI] Response: \(status!) - \(NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!)")
                respData = data
                semaphore.signal()
            } else {
                print("[TDAPI] ERROR Response: \(status!)")
                semaphore.signal();
            }
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        return (status!, respData)
    }

    /*!
     * Synchronously do a POST request
     */
    private func post(_ path: String, params: [String: String] = [:], headers: [String: String] = [:]) -> (Int, [String: Any]?) {
        var req: URLRequest = URLRequest(url: URL(string: "\(endpoint)/\(path)")!)
        req.httpMethod = "POST"
        req.setValue("TD1 \(apiKey)", forHTTPHeaderField: "Authorization")

        headers.forEach {
            req.setValue($1, forHTTPHeaderField: $0)
        }
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var reqParams = URLComponents()
        reqParams.queryItems = params.map {
            param in
            URLQueryItem(name: param.key, value: param.value)
        }
        var encodedParams = reqParams.url!.relativeString
        encodedParams = String(encodedParams[encodedParams.index(encodedParams.startIndex, offsetBy: 1)...])
        req.httpBody = encodedParams.data(using: .utf8)

        var status: Int?
        var respData: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)

        if debug {
            print("[TDAPI] Request: \(req.httpMethod!) \(req.url!.absoluteString) - \(encodedParams)")
        }

        let dataTask: URLSessionDataTask = URLSession.shared.dataTask(with: req) {
            data, response, error in
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse;
            status = httpResponse.statusCode
            if (httpResponse.statusCode == 200) {
                if self.debug {
                    print("[TDAPI] Received response \(status!) - \(NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!)\n")
                }
                respData = try! JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
                semaphore.signal()
            } else {
                print("[TDAPI] Error response - \(status!)")
                semaphore.signal();
            }
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        return (status!, respData)
    }
}
