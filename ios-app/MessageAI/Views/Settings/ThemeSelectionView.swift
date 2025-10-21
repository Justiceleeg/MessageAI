//
//  ThemeSelectionView.swift
//  MessageAI
//
//  Created by Dev Agent on 10/21/25.
//

import SwiftUI

struct ThemeSelectionView: View {
    
    // MARK: - Environment Objects
    
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - Body
    
    var body: some View {
        List {
            Section {
                // System Default Option
                Button(action: {
                    themeManager.setTheme(.system)
                }) {
                    HStack {
                        Image(systemName: "gear.badge")
                            .foregroundStyle(.blue)
                            .frame(width: 24, height: 24)
                        
                        Text("System Default")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if themeManager.currentTheme == .system {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .accessibilityLabel("System Default")
                .accessibilityHint("Use the device's system appearance setting")
                .accessibilityAddTraits(themeManager.currentTheme == .system ? [.isSelected] : [])
                
                // Light Mode Option
                Button(action: {
                    themeManager.setTheme(.light)
                }) {
                    HStack {
                        Image(systemName: "sun.max")
                            .foregroundStyle(.yellow)
                            .frame(width: 24, height: 24)
                        
                        Text("Light")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if themeManager.currentTheme == .light {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .accessibilityLabel("Light")
                .accessibilityHint("Always use light appearance")
                .accessibilityAddTraits(themeManager.currentTheme == .light ? [.isSelected] : [])
                
                // Dark Mode Option
                Button(action: {
                    themeManager.setTheme(.dark)
                }) {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundStyle(.indigo)
                            .frame(width: 24, height: 24)
                        
                        Text("Dark")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if themeManager.currentTheme == .dark {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .accessibilityLabel("Dark")
                .accessibilityHint("Always use dark appearance")
                .accessibilityAddTraits(themeManager.currentTheme == .dark ? [.isSelected] : [])
            } header: {
                Text("Choose how MessageAI looks on this device")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("System Theme") {
    NavigationStack {
        ThemeSelectionView()
            .environmentObject({
                let manager = ThemeManager()
                manager.setTheme(.system)
                return manager
            }())
    }
}

#Preview("Light Theme") {
    NavigationStack {
        ThemeSelectionView()
            .environmentObject({
                let manager = ThemeManager()
                manager.setTheme(.light)
                return manager
            }())
    }
}

#Preview("Dark Theme") {
    NavigationStack {
        ThemeSelectionView()
            .environmentObject({
                let manager = ThemeManager()
                manager.setTheme(.dark)
                return manager
            }())
    }
    .preferredColorScheme(.dark)
}

