//
//  AboutUsView.swift
//  ClippyIsle
//
//  Created for About Us section
//

import SwiftUI

struct AboutUsView: View {
    @Environment(\.dismiss) var dismiss
    
    private let aboutLogoSize: CGFloat = 100
    private let aboutLogoCornerRadius: CGFloat = 22
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // App Logo
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: aboutLogoSize, height: aboutLogoSize)
                    .cornerRadius(aboutLogoCornerRadius)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.top, 30)
                
                // App Name
                Text("Clippy Isle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                // Version
                Text("Version \(AppVersion.versionString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal)
                
                // Description
                VStack(alignment: .leading, spacing: 15) {
                    Text("About Clippy Isle")
                        .font(.headline)
                    
                    Text("Clippy Isle is a powerful clipboard management application that helps you organize, search, and manage your clipboard history efficiently. With features like iCloud sync, speech recognition, and web management, Clippy Isle makes managing your clipboard content easier than ever.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 30)
                
                Divider()
                    .padding(.horizontal)
                
                // Features
                VStack(alignment: .leading, spacing: 15) {
                    Text("Key Features")
                        .font(.headline)
                    
                    FeatureRow(icon: "doc.on.clipboard", title: "Clipboard History", description: "Never lose your copied content")
                    FeatureRow(icon: "icloud", title: "iCloud Sync", description: "Sync across all your devices")
                    FeatureRow(icon: "mic.fill", title: "Voice Search", description: "Find items with your voice")
                    FeatureRow(icon: "waveform", title: "Audio Management", description: "Manage audio files efficiently")
                    FeatureRow(icon: "tag", title: "Smart Tags", description: "Organize with tags")
                    FeatureRow(icon: "globe", title: "Web Management", description: "Manage via web browser")
                }
                .padding(.horizontal, 30)
                
                Divider()
                    .padding(.horizontal)
                
                // Developer Info
                VStack(spacing: 10) {
                    Text("Developer")
                        .font(.headline)
                    
                    Text("jasonlin0001-a11y")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("About Us")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        AboutUsView()
    }
}
