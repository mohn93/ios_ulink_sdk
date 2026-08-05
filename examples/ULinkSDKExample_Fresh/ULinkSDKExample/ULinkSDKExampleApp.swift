//
//  ULinkSDKExampleApp.swift
//  ULinkSDKExample
//
//  Created by ULinkSDK Example
//

import SwiftUI
import ULinkSDK

@main
struct ULinkSDKExampleApp: App {
    @StateObject private var viewModel = ULinkTestViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Initialize ULink SDK on app launch
                    viewModel.initializeULink()
                }
                .onOpenURL { url in
                    // Handle both custom scheme and universal links.
                    //
                    // The static entry point, not ULink.shared: on a cold
                    // launch this fires before initializeULink() above has
                    // finished, and `shared` traps when the SDK is not ready
                    // yet. The URL is buffered and replayed after init.
                    ULink.handleIncomingURL(url)
                }
        }
    }
}