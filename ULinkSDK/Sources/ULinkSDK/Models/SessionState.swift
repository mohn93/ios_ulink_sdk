//
//  SessionState.swift
//  ULinkSDK
//
//  Created by ULink SDK
//

import Foundation

/**
 * Session states for tracking session lifecycle
 *
 * This enum represents the different states a session can be in during its lifecycle.
 * It helps track the current status of session operations and provides better
 * state management for the ULink SDK.
 */
public enum SessionState {
    /**
     * No session operation in progress
     * This is the initial state and the state after a session has ended
     */
    case idle
    
    /**
     * Session start request sent, waiting for response
     * The SDK is currently attempting to start a new session
     */
    case initializing
    
    /**
     * Session successfully started and is currently active
     * The session is running and can be used for tracking
     */
    case active
    
    /**
     * Session end request sent, waiting for response
     * The SDK is currently attempting to end the active session
     */
    case ending
    
    /**
     * Session start/end failed
     * An error occurred during session initialization or termination
     */
    case failed
}