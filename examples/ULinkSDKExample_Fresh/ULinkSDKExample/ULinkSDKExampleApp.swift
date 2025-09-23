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
                    // Handle both custom scheme and universal links
                    ULink.shared.handleIncomingURL(url)
                }
        }
    }
}