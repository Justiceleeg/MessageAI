//
//  ConversationListView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import SwiftUI

struct ConversationListView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
                
                Spacer()
                    .frame(height: 40)
                
                Button("Sign Out") {
                    authViewModel.signOut()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Messages")
        }
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}

