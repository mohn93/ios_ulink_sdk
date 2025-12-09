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
        
        let (data, _) = try await performRequest(request)
        
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
            let (data, httpResponse) = try await performRequest(request)
            
            // Check for HTTP errors before decoding
            if !(200...299 ~= httpResponse.statusCode) {
                if debug {
                    print("[ULink HTTPClient] HTTP Error: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[ULink HTTPClient] Error Response: \(responseString)")
                    }
                }
                throw ULinkHTTPError(statusCode: httpResponse.statusCode, responseBody: String(data: data, encoding: .utf8))
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch let decodingError {
                if debug {
                    print("[ULink HTTPClient] JSON Decoding failed: \(decodingError)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[ULink HTTPClient] Response that failed to decode: \(responseString)")
                    }
                }
                throw decodingError
            }
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
            let (data, httpResponse) = try await performRequest(request)
            
            // Try to deserialize JSON response regardless of HTTP status
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // If JSON deserialization fails and we have an HTTP error, throw HTTP error with raw response
                if !(200...299 ~= httpResponse.statusCode) {
                    let responseString = String(data: data, encoding: .utf8)
                    if debug {
                        print("[ULink HTTPClient] HTTP Error \(httpResponse.statusCode) with invalid JSON")
                        if let responseString = responseString {
                            print("[ULink HTTPClient] Error Response Body: \(responseString)")
                        }
                    }
                    throw ULinkHTTPError(statusCode: httpResponse.statusCode, responseBody: responseString)
                }
                throw ULinkError.invalidResponse
            }
            
            // Check for HTTP error after successful JSON deserialization
            if !(200...299 ~= httpResponse.statusCode) {
                if debug {
                    print("[ULink HTTPClient] HTTP Error \(httpResponse.statusCode) with JSON response")
                    print("[ULink HTTPClient] Error Response JSON: \(json)")
                }
                // Include the deserialized JSON in the error
                throw ULinkHTTPError(statusCode: httpResponse.statusCode, responseBody: nil, responseJSON: json)
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
            let (data, httpResponse) = try await performRequest(request)
            
            // Try to deserialize JSON response regardless of HTTP status
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // If JSON deserialization fails and we have an HTTP error, throw HTTP error with raw response
                if !(200...299 ~= httpResponse.statusCode) {
                    let responseString = String(data: data, encoding: .utf8)
                    if debug {
                        print("[ULink HTTPClient] HTTP Error \(httpResponse.statusCode) with invalid JSON")
                        if let responseString = responseString {
                            print("[ULink HTTPClient] Error Response Body: \(responseString)")
                        }
                    }
                    throw ULinkHTTPError(statusCode: httpResponse.statusCode, responseBody: responseString)
                }
                throw ULinkError.invalidResponse
            }
            
            // Check for HTTP error after successful JSON deserialization
            if !(200...299 ~= httpResponse.statusCode) {
                if debug {
                    print("[ULink HTTPClient] HTTP Error \(httpResponse.statusCode) with JSON response")
                    print("[ULink HTTPClient] Error Response JSON: \(json)")
                }
                // Include the deserialized JSON in the error
                throw ULinkHTTPError(statusCode: httpResponse.statusCode, responseBody: nil, responseJSON: json)
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
            let (data, _) = try await performRequest(request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if debug {
                print("[ULink HTTPClient] DELETE request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
            
            return (data, httpResponse)
        } catch {
            if debug {
                print("[ULink HTTPClient] Request failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
}