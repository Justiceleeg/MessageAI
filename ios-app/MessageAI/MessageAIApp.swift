//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import FirebaseAuth
import FirebaseCore
import SwiftData
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    // Best-effort attempt to set offline on app termination (Story 3.3)
    // Note: onDisconnect() in RTDB handles this automatically if this fails
    func applicationWillTerminate(_ application: UIApplication) {
        if let userId = Auth.auth().currentUser?.uid {
            print("📱 App terminating - setting presence offline (best effort)")
            // Create PresenceService on-demand (Firebase is already configured at this point)
            let presenceService = PresenceService()
            presenceService.goOffline(userId: userId)
        }
    }
}

@main
struct message_aiApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Auth view model shared across the app
    @StateObject private var authViewModel = AuthViewModel()
    
    // Theme manager shared across the app
    @StateObject private var themeManager = ThemeManager()
    
    // Track scene phase for app lifecycle (Story 3.3)
    @Environment(\.scenePhase) private var scenePhase
    
    // Presence service for lifecycle management (Story 3.3)
    // Safe to create here because PresenceService uses lazy database initialization
    private let presenceService = PresenceService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .modelContainer(PersistenceController.shared.modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }
    
    // MARK: - App Lifecycle Management (Story 3.3)
    
    /// Handle app lifecycle transitions for presence management
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        guard let userId = authViewModel.authService.currentUser?.userId else {
            // No authenticated user, skip presence updates
            return
        }
        
        switch newPhase {
        case .active:
            // App moved to foreground - set user online
            // PresenceService has built-in debouncing to prevent rapid updates
            print("📱 App became active - setting presence online")
            presenceService.goOnline(userId: userId)
            
        case .background, .inactive:
            // App moved to background or became inactive - set user offline
            print("📱 App entered background/inactive - setting presence offline")
            presenceService.goOffline(userId: userId)
            
        @unknown default:
            break
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication-based routing
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Presence service for setting user online on authentication (Story 3.3)
    private let presenceService = PresenceService()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                ConversationListView(
                    firestoreService: authViewModel.firestoreService,
                    authService: authViewModel.authService
                )
                .onAppear {
                    // Set user online immediately when authenticated view appears (Story 3.3)
                    if let userId = authViewModel.authService.currentUser?.userId {
                        print("📱 User authenticated - setting presence online immediately")
                        presenceService.goOnline(userId: userId, immediate: true)
                    }
                }
            } else {
                LoginView()
            }
        }
    }
}
