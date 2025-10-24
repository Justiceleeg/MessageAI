//
//  Config.swift
//  MessageAI
//
//  Configuration management for environment-specific values
//

import Foundation

enum Config {
    
    // MARK: - Backend Configuration
    
    /// Backend URL based on build configuration
    static var backendURL: String {
        // First, try to get from Info.plist (set via xcconfig)
        if let urlString = Bundle.main.object(forInfoKey: "AI_BACKEND_URL") as? String,
           !urlString.isEmpty {
            return urlString
        }
        
        // Fallback: Use compile-time flags
        #if DEBUG
        return "http://127.0.0.1:8000"  // Local development
        #else
        return "https://messageai-backend-egkh.onrender.com"  // Production
        #endif
    }
    
    // MARK: - Environment Detection
    
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var environment: String {
        isDebug ? "Development" : "Production"
    }
    
    // MARK: - Logging
    
    static func printConfiguration() {
        print("🔧 MessageAI Configuration")
        print("   Environment: \(environment)")
        print("   Backend URL: \(backendURL)")
        print("   Debug Mode: \(isDebug)")
    }
}

