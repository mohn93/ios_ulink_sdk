//
//  HTTPClient.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * HTTP client for making async/await network requests
 * Provides a clean async/await interface for network operations
 */
public class HTTPClient {
    private let session: URLSession
    private let debug: Bool
    
    init(debug: Bool = false) {
        self.debug = debug
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - GET Requests
    
    func get<T: Codable>(
        url: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let requestUrl = URL(string: url) else {
            throw ULinkError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if debug {
            print("[ULink HTTPClient] GET \(url)")
        }
        
        let data = try await performRequest(request)
        
        if debug {
            if let responseString = String(data: data, encoding: .utf8) {
                print("[ULink HTTPClient] Response Body: \(responseString)")
            }
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - POST Requests
    
    func post<T: Codable>(
        url: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let requestUrl = URL(string: url) else {
            throw ULinkError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
        } catch {
            throw ULinkError.invalidResponse
        }
        
        do {
            let data = try await performRequest(request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if debug {
                print("[ULink HTTPClient] POST request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - POST Requests (Raw JSON)
    
    func postJson(
        url: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        guard let requestUrl = URL(string: url) else {
            throw ULinkError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ULinkError.invalidParameters
        }
        
        do {
            let data = try await performRequest(request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ULinkError.invalidResponse
            }
            
            return json
        } catch {
            if debug {
                print("[ULink HTTPClient] POST JSON request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - DELETE Requests
    
    func getJson(
        url: String,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        guard let requestUrl = URL(string: url) else {
            throw ULinkError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let data = try await performRequest(request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ULinkError.invalidResponse
            }
            
            return json
        } catch {
            if debug {
                print("[ULink HTTPClient] GET JSON request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    func delete<T: Codable>(
        url: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let requestUrl = URL(string: url) else {
            throw ULinkError.invalidURL
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "DELETE"
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if debug {
            print("[ULink HTTPClient] DELETE \(url)")
        }
        
        do {
            let data = try await performRequest(request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if debug {
                print("[ULink HTTPClient] DELETE request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            if debug {
                print("[ULink HTTPClient] \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "unknown URL")")
                print("[ULink HTTPClient] Request Headers: \(request.allHTTPHeaderFields ?? [:])")
                if let bodyData = request.httpBody,
                   let bodyString = String(data: bodyData, encoding: .utf8) {
                    print("[ULink HTTPClient] Request Body: \(bodyString)")
                }
            }
            
            let (data, response): (Data, URLResponse)
            if #available(macOS 12.0, iOS 15.0, *) {
                (data, response) = try await session.data(for: request)
            } else {
                // Fallback for older versions
                throw ULinkError.networkError
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ULinkError.invalidResponse
            }
            
            if debug {
                print("[ULink HTTPClient] Response status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[ULink HTTPClient] Response Body: \(responseString)")
                }
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                if debug {
                    print("[ULink HTTPClient] HTTP Error \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[ULink HTTPClient] Error Response Body: \(responseString)")
                    }
                }
                throw ULinkError.httpError
            }
            
            return data
        } catch {
            if debug {
                print("[ULink HTTPClient] Request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
}