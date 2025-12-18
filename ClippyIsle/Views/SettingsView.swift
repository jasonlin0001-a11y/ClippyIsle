import SwiftUI
import WebKit
import UniformTypeIdentifiers
import AVFoundation
import UIKit
import StoreKit

// MARK: - Extensions for Identifiable URL
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Settings Components
struct SettingsModalPresenterView: View {
    @Binding var isShowingTrash: Bool
    @Binding var exportURL: URL?
    @Binding var isImporting: Bool
    @Binding var isShowingImportAlert: Bool
    @Binding var importAlertMessage: String?
    @Binding var isShowingClearCacheAlert: Bool
    @Binding var isShowingCacheClearedAlert: Bool
    @Binding var isShowingHardResetAlert: Bool
    @Binding var confirmationText: String
    @Binding var isShowingTagExport: Bool
    @ObservedObject var clipboardManager: ClipboardManager
    let dismissAction: () -> Void

    var body: some View {
        EmptyView()
            .sheet(isPresented: $isShowingTrash) { TrashView(clipboardManager: clipboardManager) }
            .sheet(item: $exportURL) { url in ActivityView(activityItems: [url]) }
            .sheet(isPresented: $isShowingTagExport) { TagExportSelectionView(clipboardManager: clipboardManager, exportURL: $exportURL, isShowingImportAlert: $isShowingImportAlert, importAlertMessage: $importAlertMessage) }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in handleImport(result: result) }
            .alert("Import Result", isPresented: $isShowingImportAlert, presenting: importAlertMessage) { msg in Button("OK") {} } message: { msg in Text(msg) }
            .alert("Clear Website Cache?", isPresented: $isShowingClearCacheAlert) {
                Button("Clear", role: .destructive) { clearWebViewCache() }; Button("Cancel", role: .cancel) {}
            } message: { Text("This will remove all cookies, login sessions, and cached data for websites viewed within the app. This action cannot be undone.") }
            .alert("Cache Cleared", isPresented: $isShowingCacheClearedAlert) { Button("OK") {} } message: { Text("All website data has been successfully cleared.") }
            .alert("Permanently Delete All Data?", isPresented: $isShowingHardResetAlert) {
                TextField("Type DELETE to confirm", text: $confirmationText).autocorrectionDisabled(true).autocapitalization(.allCharacters)
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { clipboardManager.hardResetData(); dismissAction() }.disabled(confirmationText != "DELETE")
            } message: { Text("This action cannot be undone. Please type 'DELETE' in all capital letters to confirm you want to permanently delete all items.") }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { importAlertMessage = "No file selected."; isShowingImportAlert = true; return }
            if url.pathExtension.lowercased() != "json" { importAlertMessage = "Invalid file format.\nPlease select a .json backup file."; isShowingImportAlert = true; return }
            do { let count = try clipboardManager.importData(from: url); importAlertMessage = "Import successful!\nAdded \(count) new items." }
            catch { importAlertMessage = "Import failed.\nError: \(error.localizedDescription)" }
        case .failure(let error): importAlertMessage = "Could not select file.\nError: \(error.localizedDescription)"
        }
        isShowingImportAlert = true
    }
    private func clearWebViewCache() {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) {
            print("✅ Web cache cleared successfully."); isShowingCacheClearedAlert = true
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showPaywall = false
    
    @Binding var themeColorName: String
    @State private var isShowingTrash = false
    
    // Web Server State
    @StateObject private var webServer = WebServerManager.shared
    
    // User Nickname Storage (local backup + UI state)
    @AppStorage("userNickname") private var userNickname: String = ""
    @State private var nicknameInput: String = ""
    @State private var isNicknameSaved: Bool = false
    @State private var isSavingNickname: Bool = false
    
    // Custom Color Storage
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    @AppStorage("askToAddFromClipboard") private var askToAddFromClipboard: Bool = true
    @AppStorage("maxItemCount") private var maxItemCount: Int = 100
    @AppStorage("clearAfterDays") private var clearAfterDays: Int = 30
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue
    @ObservedObject var speechManager: SpeechManager
    @AppStorage("showSpeechSubtitles") private var showSpeechSubtitles: Bool = true
    @AppStorage("previewFontSize") private var previewFontSize: Double = 17.0
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    @State private var isShowingClearCacheAlert = false
    @State private var isShowingCacheClearedAlert = false
    @State private var isShowingHardResetAlert = false
    @State private var confirmationText = ""
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var importAlertMessage: String?
    @State private var isShowingImportAlert = false
    @State private var isShowingTagExport = false
    
    // Firebase password settings
    @AppStorage("firebasePasswordEnabled") private var firebasePasswordEnabled: Bool = false
    @AppStorage("firebasePassword") private var firebasePassword: String = ""
    @State private var passwordInput: String = ""
    @State private var isPasswordSaved: Bool = false
    
    // iCloud purge state
    @State private var isShowingPurgeCloudAlert = false
    @State private var isPurgingCloud = false
    @State private var purgeCloudResult: String?
    @State private var isShowingPurgeResultAlert = false

    let countOptions = [50, 100, 200, 0]
    let dayOptions = [7, 30, 90, 0]
    let colorOptions = ["blue", "green", "neonGreen", "orange", "red", "pink", "purple", "black", "white", "retro", "custom"]
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: customColorRed, green: customColorGreen, blue: customColorBlue) },
            set: {
                let uiColor = UIColor($0)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                customColorRed = Double(r)
                customColorGreen = Double(g)
                customColorBlue = Double(b)
                
                clipboardManager.userDefaults.set(Double(r), forKey: "customColorRed")
                clipboardManager.userDefaults.set(Double(g), forKey: "customColorGreen")
                clipboardManager.userDefaults.set(Double(b), forKey: "customColorBlue")
                
                if clipboardManager.isLiveActivityOn && themeColorName == "custom" {
                    clipboardManager.updateActivity(newColorName: "custom")
                }
            }
        )
    }
    
    var preferredColorScheme: ColorScheme? { AppearanceMode(rawValue: appearanceMode)?.colorScheme }

    var body: some View {
        NavigationView {
            Form {
                premiumSection
                nicknameSection
                
                Section(header: Text("Web Management"), footer: Text("Allows managing items via a web browser on the same Wi-Fi network.")) {
                    Toggle("Enable Web Server", isOn: Binding(
                        get: { webServer.isRunning },
                        set: { newValue in
                            if newValue {
                                if subscriptionManager.isPro { webServer.start() }
                                else { showPaywall = true }
                            } else { webServer.stop() }
                        }
                    ))
                    
                    if webServer.isRunning, let url = webServer.serverURL {
                        HStack {
                            Text("URL"); Spacer()
                            Text(url).foregroundColor(.blue).onTapGesture {
                                UIPasteboard.general.string = url
                                let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
                    }
                        }
                        Text("Tap URL to copy").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("General"), footer: Text("When enabled, the app will automatically detect and add new items from the clipboard. When disabled, you must add items manually from the '+' menu on the main screen.")) { Toggle("Auto Add from Clipboard", isOn: $askToAddFromClipboard) }
                storagePolicySection; appearanceSection; previewSettingsSection; speechSettingsSection; iCloudSection; backupAndRestoreSection; firebaseSettingsSection; dataManagementSection; appInfoSection
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .background(SettingsModalPresenterView(isShowingTrash: $isShowingTrash, exportURL: $exportURL, isImporting: $isImporting, isShowingImportAlert: $isShowingImportAlert, importAlertMessage: $importAlertMessage, isShowingClearCacheAlert: $isShowingClearCacheAlert, isShowingCacheClearedAlert: $isShowingCacheClearedAlert, isShowingHardResetAlert: $isShowingHardResetAlert, confirmationText: $confirmationText, isShowingTagExport: $isShowingTagExport, clipboardManager: clipboardManager, dismissAction: { dismiss() }))
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear {
                WebServerManager.shared.clipboardManager = clipboardManager
                // Initialize nickname from AuthenticationManager or fallback to local storage
                nicknameInput = authManager.userProfile?.nickname ?? userNickname
                clipboardManager.userDefaults.set(customColorRed, forKey: "customColorRed")
                clipboardManager.userDefaults.set(customColorGreen, forKey: "customColorGreen")
                clipboardManager.userDefaults.set(customColorBlue, forKey: "customColorBlue")
            }
            // Update nicknameInput when userProfile changes (e.g., after sign-in completes)
            .onChange(of: authManager.userProfile?.nickname) { _, newNickname in
                if let nickname = newNickname, nicknameInput.isEmpty || nicknameInput == userNickname {
                    nicknameInput = nickname
                }
            }
        }.tint(themeColor).id(themeColorName).preferredColorScheme(preferredColorScheme)
    }

    private var premiumSection: some View {
        Section {
            if subscriptionManager.isPro {
                HStack { Image(systemName: "crown.fill").foregroundColor(.yellow); Text("You are a Pro User"); Spacer(); Text("Active").foregroundColor(.secondary) }
            } else {
                Button(action: { showPaywall = true }) {
                    HStack { Image(systemName: "crown.fill").foregroundColor(.yellow); Text("Upgrade to Pro").fontWeight(.medium).foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }
                }
            }
        } header: { Text("Premium Access") }
    }

    private var nicknameSection: some View {
        Section(header: Text("User Profile"), footer: Text("Your nickname will be displayed when sharing items (e.g., 'Shared by Alex').")) {
            HStack {
                Text("Nickname")
                TextField("Enter your name", text: $nicknameInput)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .onChange(of: nicknameInput) { _, _ in isNicknameSaved = false }
                    .disabled(isSavingNickname)
                
                if isSavingNickname {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if nicknameInput != (authManager.userProfile?.nickname ?? userNickname) || isNicknameSaved {
                    Button(action: saveNickname) {
                        if isNicknameSaved { 
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green) 
                        } else { 
                            Text("Save").fontWeight(.bold) 
                        }
                    }
                    .buttonStyle(.borderless)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut, value: isNicknameSaved)
                }
            }
            
            // Show User ID (full, long press to copy)
            HStack {
                Text("User ID")
                Spacer()
                if let uid = authManager.currentUID ?? authManager.userProfile?.uid {
                    Text(uid)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .textSelection(.enabled)
                        .onLongPressGesture {
                            UIPasteboard.general.string = uid
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                } else if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    // Show error or retry option
                    Button(action: {
                        Task {
                            try? await authManager.signInAnonymously()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Tap to sign in")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Show auth error if any
            if let error = authManager.authError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption2)
            }
        }
    }
    
    private func saveNickname() {
        guard !nicknameInput.isEmpty else { return }
        
        isSavingNickname = true
        
        Task {
            do {
                // Save to Firestore via AuthenticationManager
                try await authManager.updateNickname(nicknameInput)
                
                // Also save locally as backup
                await MainActor.run {
                    userNickname = nicknameInput
                    isNicknameSaved = true
                    isSavingNickname = false
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                // Reset the saved indicator after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    if self.nicknameInput == (authManager.userProfile?.nickname ?? userNickname) {
                        self.isNicknameSaved = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSavingNickname = false
                    // Show error feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    print("❌ Failed to save nickname: \(error.localizedDescription)")
                }
            }
        }
    }

    private var storagePolicySection: some View {
        Section("Storage Policy") {
            Picker("Max Item Count", selection: $maxItemCount) { ForEach(countOptions, id: \.self) { Text($0 == 0 ? "Unlimited" : "\($0) items").tag($0) } }
            Picker("Auto-clean Days", selection: $clearAfterDays) { ForEach(dayOptions, id: \.self) { Text($0 == 0 ? "Never" : "\($0) days ago").tag($0) } }
            Text("The app automatically cleans up old or redundant 'unpinned' items on launch. If set to 'Unlimited' or 'Never', the corresponding rule is disabled.").font(.caption).foregroundColor(.secondary).padding(.top, 5)
        }
    }
    
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Display Mode", selection: $appearanceMode) { ForEach(AppearanceMode.allCases) { Text($0.name).tag($0.rawValue) } }.pickerStyle(.segmented)
            Picker("Theme Color", selection: $themeColorName) {
                ForEach(colorOptions, id: \.self) { colorName in
                    let colorToShow: Color = (colorName == "custom") ? Color(red: customColorRed, green: customColorGreen, blue: customColorBlue) : ClippyIsleAttributes.ColorUtility.color(forName: colorName)
                    HStack {
                        Image(systemName: "circle.fill").foregroundColor(colorToShow)
                        if colorName == "custom" && !subscriptionManager.isPro {
                            Text("Custom (Pro)").foregroundColor(.secondary)
                            Image(systemName: "lock.fill").font(.caption).foregroundColor(.secondary)
                        } else { 
                            Text(colorName == "retro" ? "Retro" : (colorName == "neonGreen" ? "Neon Green" : colorName.capitalized)) 
                        }
                    }.tag(colorName).tint(colorToShow)
                }
            }
            if themeColorName == "custom" {
                if subscriptionManager.isPro { ColorPicker("Custom Color", selection: customColorBinding, supportsOpacity: false) }
                else { Button(action: { showPaywall = true }) { HStack { Text("Unlock Custom Color"); Spacer(); Image(systemName: "lock.fill").foregroundColor(.orange) } } }
            }
        }
    }
    
    private var previewSettingsSection: some View {
        Section("Preview Settings") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Font Size: \(Int(previewFontSize))"); Slider(value: $previewFontSize, in: 12...28, step: 1)
                HStack { Text("Smaller"); Spacer(); Text("Larger") }.font(.caption)
            }.padding(.vertical, 5)
        }
    }
    private var speechSettingsSection: some View {
        Section("Speech Settings") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Speech Rate: \(String(format: "%.1fx", speechManager.speechRate))").font(.body)
                Slider(value: $speechManager.speechRate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate), step: 0.05)
                HStack { Text("Slower"); Spacer(); Text("Standard"); Spacer(); Text("Faster") }.font(.caption)
            }.padding(.vertical, 5)
            Toggle("Speech Subtitles", isOn: $showSpeechSubtitles)
        }
    }
    
    private var iCloudSection: some View {
        Section(header: Text("iCloud Sync"), footer: Text("Data is stored in your private iCloud database. Images are synced automatically.")) {
            Toggle("Enable iCloud Sync", isOn: Binding(
                get: { iCloudSyncEnabled },
                set: { newValue in
                    if newValue { if subscriptionManager.isPro { iCloudSyncEnabled = true } else { showPaywall = true } }
                    else { iCloudSyncEnabled = false }
                }
            ))
            
            if iCloudSyncEnabled {
                HStack { Text("Status"); Spacer(); Text(clipboardManager.cloudKitManager.iCloudStatus).foregroundColor(.secondary) }
                // **MODIFIED**: Sync Now Button Lock
                Button {
                    if subscriptionManager.isPro {
                        Task { await clipboardManager.performCloudSync() }
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Text("Sync Now")
                            // IAP Logic: Grey out text if not Pro
                            .foregroundColor(subscriptionManager.isPro ? .blue : .gray)
                        Spacer()
                        if clipboardManager.cloudKitManager.isSyncing { ProgressView() }
                        else if !subscriptionManager.isPro { Image(systemName: "lock.fill").font(.caption).foregroundColor(.gray) }
                    }
                }
                .disabled(clipboardManager.cloudKitManager.isSyncing) // Still disable while syncing
            }
        }
    }
    
    private var backupAndRestoreSection: some View {
        Section("Backup and Restore") {
            Button { isImporting = true } label: { Text("Import Data") }
            Button(action: exportAllData) { Text("Export All Data") }
            Button { isShowingTagExport = true } label: { Text("Selective Export...") }
        }
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button { isShowingTrash = true } label: { Text("Trash") }
            NavigationLink { AudioFileManagerView(clipboardManager: clipboardManager, speechManager: speechManager) } label: { Text("Manage Audio Files") }
            Button("Clear Website Cache", role: .destructive) { isShowingClearCacheAlert = true }
            Button("Clear All Data", role: .destructive) { confirmationText = ""; isShowingHardResetAlert = true }
            
            // iCloud Purge Button (Nuclear Option for clearing zombie data)
            Button(role: .destructive) {
                isShowingPurgeCloudAlert = true
            } label: {
                HStack {
                    if isPurgingCloud {
                        ProgressView()
                    }
                    Text("Purge iCloud Data")
                }
            }
            .disabled(isPurgingCloud)
        }
        .alert("Purge All iCloud Data?", isPresented: $isShowingPurgeCloudAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                purgeCloudData()
            }
        } message: {
            Text("This will permanently delete ALL clipboard items and tag colors from your iCloud account. This cannot be undone. Use this to clear corrupt or zombie data that's causing sync issues.")
        }
        .alert("Purge Result", isPresented: $isShowingPurgeResultAlert) {
            Button("OK") {}
        } message: {
            Text(purgeCloudResult ?? "Unknown result")
        }
    }
    
    private func purgeCloudData() {
        isPurgingCloud = true
        Task {
            let result = await clipboardManager.purgeAllCloudData()
            await MainActor.run {
                isPurgingCloud = false
                switch result {
                case .success(let count):
                    purgeCloudResult = "Successfully deleted \(count) records from iCloud."
                case .failure(let error):
                    purgeCloudResult = "Purge failed: \(error.localizedDescription)"
                }
                isShowingPurgeResultAlert = true
            }
        }
    }
    
    private var firebaseSettingsSection: some View {
        Section(header: Text("Firebase Share Settings")) {
            Toggle("Enable Password Protection", isOn: $firebasePasswordEnabled)
            
            if firebasePasswordEnabled {
                HStack {
                    Text("Password")
                    SecureField("Enter password", text: $passwordInput)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .onChange(of: passwordInput) { _, _ in isPasswordSaved = false }
                        .onAppear { passwordInput = firebasePassword }
                    if passwordInput != firebasePassword || isPasswordSaved {
                        Button(action: savePassword) {
                            if isPasswordSaved { 
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green) 
                            } else { 
                                Text("Save").fontWeight(.bold) 
                            }
                        }
                        .buttonStyle(.borderless)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut, value: isPasswordSaved)
                    }
                }
            }
        }
    }
    
    private func savePassword() {
        guard !passwordInput.isEmpty else { return }
        firebasePassword = passwordInput
        isPasswordSaved = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { 
            if self.passwordInput == self.firebasePassword { 
                self.isPasswordSaved = false 
            } 
        }
    }
    
    private var appInfoSection: some View {
        Section("App Information") {
            HStack {
                Text("Version")
                Spacer()
                Text(AppVersion.versionString)
                    .foregroundColor(.secondary)
            }
            
            NavigationLink {
                AboutUsView()
            } label: {
                Text("About Us")
            }
        }
    }
    
    private func exportAllData() {
        do { exportURL = try clipboardManager.exportData() } catch { importAlertMessage = "Export failed.\nError: \(error.localizedDescription)"; isShowingImportAlert = true }
    }
}