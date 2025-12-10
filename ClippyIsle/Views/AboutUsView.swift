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
    
    // Detect system language for privacy policy
    private var isChineseLanguage: Bool {
        return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }
    
    private var privacyPolicyTitle: String {
        isChineseLanguage ? "隱私權政策" : "Privacy Policy"
    }
    
    private var privacyPolicyContent: String {
        if isChineseLanguage {
            return """
            隱私權政策
            
            C Isle 尊重並保護所有使用者的隱私權。本隱私權政策說明我們如何處理您的資訊。
            
            資料收集
            本應用程式不會收集、傳輸或分享您的個人資料給第三方。所有的剪貼簿內容都儲存在您的裝置本地或您的個人 iCloud 帳戶中。
            
            資料使用
            • 剪貼簿內容僅在您的裝置上處理
            • 如啟用 iCloud 同步，資料將透過您的 iCloud 帳戶在您的裝置間同步
            • 我們不會存取、讀取或使用您的剪貼簿內容
            
            資料安全
            您的資料安全是我們的首要任務。所有資料都使用 Apple 提供的標準安全機制進行保護。
            
            您的權利
            您可以隨時透過應用程式的設定頁面刪除所有儲存的資料。
            
            政策更新
            我們可能會不時更新本隱私權政策。任何變更都會在應用程式中通知您。
            
            聯絡我們
            如果您對本隱私權政策有任何疑問，請透過 App Store 聯繫我們。
            """
        } else {
            return """
            Privacy Policy
            
            C Isle respects and protects the privacy of all users. This privacy policy explains how we handle your information.
            
            Data Collection
            This application does not collect, transmit, or share your personal data with third parties. All clipboard content is stored locally on your device or in your personal iCloud account.
            
            Data Usage
            • Clipboard content is processed only on your device
            • If iCloud sync is enabled, data will be synchronized across your devices through your iCloud account
            • We do not access, read, or use your clipboard content
            
            Data Security
            Your data security is our top priority. All data is protected using standard security mechanisms provided by Apple.
            
            Your Rights
            You can delete all stored data at any time through the app's settings page.
            
            Policy Updates
            We may update this privacy policy from time to time. Any changes will be notified to you within the application.
            
            Contact Us
            If you have any questions about this privacy policy, please contact us through the App Store.
            """
        }
    }
    
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
                Text("C Isle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                // Version
                Text("Version \(AppVersion.versionString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal)
                
                // Description
                VStack(alignment: .leading, spacing: 15) {
                    Text("About C Isle")
                        .font(.headline)
                    
                    Text("C Isle is a powerful clipboard management application that helps you organize, search, and manage your clipboard history efficiently. With features like iCloud sync, speech recognition, and web management, C Isle makes managing your clipboard content easier than ever.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 30)
                
                Divider()
                    .padding(.horizontal)
                
                // Privacy Policy
                VStack(alignment: .leading, spacing: 15) {
                    Text(privacyPolicyTitle)
                        .font(.headline)
                    
                    ScrollView {
                        Text(privacyPolicyContent)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxHeight: 300)
                }
                .padding(.horizontal, 30)
                
                Divider()
                    .padding(.horizontal)
                
                // Developer Info
                VStack(spacing: 10) {
                    Text("Developer")
                        .font(.headline)
                    
                    Text("C Isle Studio")
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

#Preview {
    NavigationView {
        AboutUsView()
    }
}
