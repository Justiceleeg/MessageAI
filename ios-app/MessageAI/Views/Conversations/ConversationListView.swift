//
//  ConversationListView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import SwiftUI

struct ConversationListView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSettings: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "message.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                Text("Welcome to MessageAI!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your conversations will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open settings and account options")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}

