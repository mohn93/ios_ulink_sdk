//
//  ULinkTestViewModel.swift
//  ULinkSDKExample
//
//  Created by ULinkSDK Example
//

import ULinkSDK
import Foundation
import Combine

@MainActor
class ULinkTestViewModel: ObservableObject {
    @Published var status: String = "Not initialized"
    @Published var sessionId: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var isInitialized: Bool = false
    @Published var receivedDeepLinkData: String = "No deep link received yet"
    @Published var lastDeepLinkUrl: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    // private var ulink: ULink? // Commented out for now
    
    init() {
        // Deep link callbacks will be set up after SDK initialization
    }
    
    private func setupDeepLinkCallbacks() {
        // Subscribe to deep link callbacks from the SDK
        ULink.shared.onLink
            .receive(on: DispatchQueue.main)
            .sink { [weak self] linkData in
                self?.handleDeepLinkData(linkData, type: "Custom Scheme")
            }
            .store(in: &cancellables)
        
        ULink.shared.onUnifiedLink
            .receive(on: DispatchQueue.main)
            .sink { [weak self] linkData in
                self?.handleDeepLinkData(linkData, type: "Universal Link")
            }
            .store(in: &cancellables)
    }
    
    private func handleDeepLinkData(_ linkData: ULinkResolvedData?, type: String) {
        guard let data = linkData else {
            receivedDeepLinkData = "\(type): No data received"
            return
        }
        
        lastDeepLinkUrl =  data.fallbackUrl ?? "Unknown URL"
        
        var dataString = "\(type) received:\n"
        dataString += "URL: \(data.iosUrl ?? "N/A")\n"
        
        if let parameters = data.parameters {
            dataString += "Parameters:\n"
            for (key, value) in parameters {
                dataString += "  \(key): \(value)\n"
            }
        }
        
        receivedDeepLinkData = dataString
    }
    
    func initializeULink() {
        isLoading = true
        errorMessage = ""
        
        let config = ULinkConfig(
            apiKey: "ulk_f666ab8b0113e922e014be89c47d04cacce70114a5b7f702",
            baseUrl: "https://api.ulink.ly",
            debug: true
        )
        
        Task {
            await ULink.initialize(config: config)

            
            // Check if a session was automatically started and capture its ID
            if let currentSessionId = ULink.shared.getCurrentSessionId() {
                await MainActor.run {
                    self.sessionId = currentSessionId
                    self.status = "ULink SDK initialized with session: \(currentSessionId)"
                    self.isInitialized = true
                    self.isLoading = false
                    self.setupDeepLinkCallbacks()
                }
            } else {
                await MainActor.run {
                    self.status = "ULink SDK initialized"
                    self.isInitialized = true
                    self.isLoading = false
                    self.setupDeepLinkCallbacks()
                }
            }
        }
    }
    
    func startSession() {
        guard isInitialized else {
            self.errorMessage = "ULink not initialized"
            return
        }
        
        self.isLoading = true
        self.errorMessage = ""
        
        Task {
            do {
                let response = try await ULink.shared.startSession()
                
                if response.success {
                    self.sessionId = response.sessionId ?? ""
                    self.status = "Session started: \(response.sessionId)"
                } else {
                    self.errorMessage = "Failed to start session"
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Error starting session: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func resolveLink(_ url: String) {
        guard isInitialized else {
            self.errorMessage = "ULink not initialized"
            return
        }
        
        self.isLoading = true
        self.errorMessage = ""
        
        Task {
            do {
                let response = try await ULink.shared.resolveLink(url: url)
                
                if response.success {
                    self.status = "Link resolved: \(response.url ?? "No URL")"
                } else {
                    self.errorMessage = "Failed to resolve link"
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Error resolving link: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func createDynamicLink() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let parameters = ULinkParameters.dynamic(
                    domain: "example.ulink.ly",
                    slug: "test-dynamic",
                    iosFallbackUrl: "https://apps.apple.com/app/example",
                    androidFallbackUrl: "https://play.google.com/store/apps/details?id=com.example",
                    fallbackUrl: "https://example.com",
                    parameters: ["utm_source": "ios_sdk", "test": "dynamic"]
                )
                
                let response = try await ULink.shared.createLink(parameters: parameters)
                
                await MainActor.run {
                    self.isLoading = false
                    if response.success {
                        self.status = "Dynamic link created: \(response.url ?? "No URL")"
                    } else {
                        self.errorMessage = response.error ?? "Failed to create dynamic link"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Error creating dynamic link: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func createUnifiedLink() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let parameters = ULinkParameters.unified(
                    domain: "example.ulink.ly",
                    slug: "test-unified",
                    iosUrl: "https://apps.apple.com/app/example",
                    androidUrl: "https://play.google.com/store/apps/details?id=com.example",
                    fallbackUrl: "https://example.com/unified",
                    parameters: ["utm_source": "ios_sdk", "test": "unified"]
                )
                
                let response = try await ULink.shared.createLink(parameters: parameters)
                
                await MainActor.run {
                    self.isLoading = false
                    if response.success {
                        self.status = "Unified link created: \(response.url ?? "No URL")"
                    } else {
                        self.errorMessage = response.error ?? "Failed to create unified link"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Error creating unified link: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func endSession() {
        guard !sessionId.isEmpty else {
            self.errorMessage = "No active session to end"
            return
        }
        
        self.isLoading = true
        self.errorMessage = ""
        
        Task {
            do {
                let response = try await ULink.shared.endSession()
                
                if response {
                    self.sessionId = ""
                    self.status = "Session ended successfully"
                } else {
                    self.errorMessage = "Failed to end session"
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Error ending session: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func getInstallationId() {
        if let installationId = ULink.shared.getInstallationId() {
            status = "Installation ID: \(installationId)"
        } else {
            status = "Installation ID: Not available"
        }
    }
    
    func getSessionState() {
        let sessionState = ULink.shared.getSessionState()
        let _ = ULink.shared.hasActiveSession()
        let currentSessionId = ULink.shared.getCurrentSessionId()
        
        var stateString = "Session State: "
        switch sessionState {
        case .idle:
            stateString += "Idle"
        case .initializing:
            stateString += "Initializing"
        case .active:
            stateString += "Active"
        case .ending:
            stateString += "Ending"
        case .failed:
            stateString += "Failed"
        }
        
        if let sessionId = currentSessionId {
            stateString += " (ID: \(sessionId))"
        }
        
        status = stateString
    }
    
    func testErrorHandling() {
        isLoading = true
        errorMessage = ""
        
        // Mock error handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.errorMessage = "Mock error: This is a test error"
            self.status = "Error occurred (Mock)"
            self.isLoading = false
        }
    }
    
    func trackInstallation() {
        guard isInitialized else {
            self.errorMessage = "ULink not initialized"
            return
        }
        
        self.isLoading = true
        self.errorMessage = ""
        
        Task {
            do {
                let response = try await ULink.shared.trackInstallation()
                
                if response.success {
                    self.status = "Installation tracked: \(response.installationToken ?? "No token")"
                } else {
                    self.errorMessage = "Failed to track installation"
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Error tracking installation: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
