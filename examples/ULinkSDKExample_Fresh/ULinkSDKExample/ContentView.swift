//
//  ContentView.swift
//  ULinkSDKExample
//
//  Created by ULinkSDK Example
//

import SwiftUI
import ULinkSDK

struct ContentView: View {
    @EnvironmentObject var viewModel: ULinkTestViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("ULink SDK Example")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status: \(viewModel.status)")
                        .font(.headline)
                    
                    if !viewModel.sessionId.isEmpty {
                        Text("Session ID: \(viewModel.sessionId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !viewModel.errorMessage.isEmpty {
                        Text("Error: \(viewModel.errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Deep Link Data Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Deep Link Data")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.receivedDeepLinkData)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                    
                    if !viewModel.lastDeepLinkUrl.isEmpty {
                        Text("Last URL: \(viewModel.lastDeepLinkUrl)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
                
                ScrollView {
                    VStack(spacing: 15) {
                        // SDK automatically initializes on app launch
                        Text("SDK Status: \(viewModel.isInitialized ? "Initialized" : "Initializing...")")
                            .font(.subheadline)
                            .foregroundColor(viewModel.isInitialized ? .green : .orange)
                            .padding(.bottom, 10)
                        
                        // Link Creation Section
                        Group {
                            Text("Link Creation")
                                .font(.headline)
                                .padding(.top)
                            
                            Button("Create Dynamic Link") {
                                viewModel.createDynamicLink()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                            
                            Button("Create Unified Link") {
                                viewModel.createUnifiedLink()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                        }
                        
                        // Session Management Section
                        Group {
                            Text("Session Management")
                                .font(.headline)
                                .padding(.top)
                            
                            Button("Start Session") {
                                viewModel.startSession()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                            
                            Button("End Session") {
                                viewModel.endSession()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                        }
                        
                        // Utility Functions Section
                        Group {
                            Text("Utility Functions")
                                .font(.headline)
                                .padding(.top)
                            
                            Button("Get Installation ID") {
                                viewModel.getInstallationId()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                            
                            Button("Get Session State") {
                                viewModel.getSessionState()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                            
                            Button("Resolve Link") {
                                viewModel.resolveLink("https://example.com/test")
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                        }
                        
                        // Testing Section
                        Group {
                            Text("Testing")
                                .font(.headline)
                                .padding(.top)
                            
                            Button("Test Error Handling") {
                                viewModel.testErrorHandling()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                            
                            Button("Track Installation") {
                                viewModel.trackInstallation()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || !viewModel.isInitialized)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ULink SDK")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ULinkTestViewModel())
}