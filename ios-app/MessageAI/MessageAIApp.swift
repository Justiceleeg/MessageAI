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
struct MessageAIApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Auth view model shared across the app
    @StateObject private var authViewModel = AuthViewModel()
    
    // Theme manager shared across the app
    @StateObject private var themeManager = ThemeManager()
    
    // Notification manager for notification system (Story 3.4)
    @State private var notificationManager = NotificationManager()
    
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
                .environment(notificationManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .overlay(alignment: .top) {
                    // In-app notification banner (Story 3.4)
                    if notificationManager.showBanner,
                       let title = notificationManager.bannerTitle,
                       let message = notificationManager.bannerMessage {
                        NotificationBannerView(
                            title: title,
                            message: message,
                            onTap: {
                                handleBannerTap()
                            },
                            onDismiss: {
                                notificationManager.dismissBanner()
                            }
                        )
                        .animation(.spring(), value: notificationManager.showBanner)
                    }
                }
        }
        .modelContainer(PersistenceController.shared.modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }
    
    // MARK: - App Lifecycle Management (Story 3.3, 3.4)
    
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
    
    // MARK: - Notification Handling (Story 3.4)
    
    /// Handle banner tap to navigate to conversation
    private func handleBannerTap() {
        if let conversationId = notificationManager.bannerConversationId {
            print("📱 Banner tapped - navigating to conversation: \(conversationId)")
            
            // Post notification for navigation
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
            
            // Dismiss banner
            notificationManager.dismissBanner()
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication-based routing
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(NotificationManager.self) private var notificationManager
    
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
                        
                        // Request notification permissions and start listening (Story 3.4)
                        Task {
                            _ = await notificationManager.requestNotificationPermissions()
                            notificationManager.startListening(userId: userId)
                        }
                    }
                }
                .onDisappear {
                    // Stop notification listener when logged out (Story 3.4)
                    notificationManager.stopListening()
                }
            } else {
                LoginView()
            }
        }
    }
}
