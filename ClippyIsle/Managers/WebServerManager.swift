import Foundation
import Network
import UIKit
import Combine
import UniformTypeIdentifiers

class WebServerManager: ObservableObject {
    static let shared = WebServerManager()
    
    @Published var isRunning = false
    @Published var serverURL: String? = nil
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8080
    private let queue = DispatchQueue(label: "com.clippyisle.webserver", qos: .userInitiated)
    
    var clipboardManager: ClipboardManager?
    
    // MARK: - Server Lifecycle
    func start() {
        guard !isRunning else { return }
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let parameters = NWParameters.tcp
                let listener = try NWListener(using: parameters, on: self.port)
                
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        print("🚀 Web Server Ready on port \(self.port.rawValue)")
                        self.updateServerURL()
                        DispatchQueue.main.async { self.isRunning = true }
                    case .failed(let error):
                        print("❌ Web Server Failed: \(error)")
                        self.stop()
                    default: break
                    }
                }
                
                listener.newConnectionHandler = { connection in
                    self.handleConnection(connection)
                }
                
                listener.start(queue: self.queue)
                self.listener = listener
            } catch {
                print("❌ Failed to create listener: \(error)")
            }
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            self.isRunning = false
            self.serverURL = nil
        }
        print("🛑 Web Server Stopped")
    }
    
    private func updateServerURL() {
        if let ip = getWiFiAddress() {
            DispatchQueue.main.async {
                self.serverURL = "http://\(ip):\(self.port.rawValue)"
            }
        }
    }
    
    // MARK: - Connection Handling
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readRequest(connection: connection, buffer: Data())
    }
    
    private func readRequest(connection: NWConnection, buffer: Data) {
        // Reverted buffer size to normal (64KB) since image upload is removed
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            guard let self = self else { return }
            
            if let data = data {
                var newBuffer = buffer
                newBuffer.append(data)
                self.checkAndProcessRequest(connection: connection, buffer: newBuffer)
            } else if let error = error {
                print("⚠️ Connection error: \(error)")
                connection.cancel()
            } else if isComplete {
                if !buffer.isEmpty {
                    self.checkAndProcessRequest(connection: connection, buffer: buffer)
                }
                connection.cancel()
            }
        }
    }
    
    private func checkAndProcessRequest(connection: NWConnection, buffer: Data) {
        guard let separatorRange = buffer.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) else {
            readRequest(connection: connection, buffer: buffer)
            return
        }
        
        let headerData = buffer.subdata(in: 0..<separatorRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            connection.cancel()
            return
        }
        
        var contentLength = 0
        let lines = headerString.components(separatedBy: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0"
                contentLength = Int(value) ?? 0
            }
        }
        
        let bodyStartIndex = separatorRange.upperBound
        let currentBodyLength = buffer.count - bodyStartIndex
        
        if currentBodyLength >= contentLength {
            let bodyData = buffer.subdata(in: bodyStartIndex..<bodyStartIndex+contentLength)
            let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
            
            processFullRequest(headerString: headerString, bodyString: bodyString, on: connection)
        } else {
            readRequest(connection: connection, buffer: buffer)
        }
    }
    
    private func processFullRequest(headerString: String, bodyString: String, on connection: NWConnection) {
        let lines = headerString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        
        let method = parts[0]
        let path = parts[1]
        
        var response = ""
        var contentType = "text/html; charset=utf-8"
        
        if method == "GET" {
            if path == "/" {
                response = generateIndexHTML()
            } else if path.hasPrefix("/edit/") {
                let id = String(path.dropFirst("/edit/".count))
                response = generateEditHTML(id: id)
            } else if path == "/new" {
                response = generateEditHTML(id: nil)
            } else if path.hasPrefix("/delete/") {
                let id = String(path.dropFirst("/delete/".count))
                deleteItem(id: id)
                response = redirectHome()
            } else if path.hasPrefix("/delete-audio/") {
                let filename = String(path.dropFirst("/delete-audio/".count))
                deleteAudioFile(filename: filename)
                response = redirectHome()
            } else if path.hasPrefix("/audio/") {
                let filename = String(path.dropFirst("/audio/".count))
                if let fileData = getAudioFileData(filename: filename) {
                    sendAudio(data: fileData, filename: filename, download: false, on: connection)
                    return
                } else {
                    response = "404 Not Found"
                }
            } else if path.hasPrefix("/download-audio/") {
                let filename = String(path.dropFirst("/download-audio/".count))
                if let fileData = getAudioFileData(filename: filename) {
                    sendAudio(data: fileData, filename: filename, download: true, on: connection)
                    return
                } else {
                    response = "404 Not Found"
                }
            } else if path == "/style.css" {
                response = cssStyles()
                contentType = "text/css"
            }
        } else if method == "POST" {
            if path == "/save" {
                handleSave(body: bodyString)
                response = redirectHome()
            } else if path == "/api/batch-delete" {
                handleBatchDelete(body: bodyString)
                response = redirectHome()
            }
        }
        
        if response.isEmpty { response = "404 Not Found" }
        
        send(response, type: contentType, on: connection)
    }
    
    private func redirectHome() -> String {
        return "<html><head><meta http-equiv=\"refresh\" content=\"0;url=/\"></head><body>Redirecting...</body></html>"
    }
    
    // MARK: - Logic Actions
    
    private func handleSave(body: String) {
        let params = parseFormData(body)
        guard var content = params["content"] else { return }
        
        // Handle URL encoding
        content = content.replacingOccurrences(of: "+", with: " ")
        content = content.removingPercentEncoding ?? content
        
        guard !content.isEmpty else { return }
        
        let idString = params["id"] ?? ""
        
        DispatchQueue.main.async {
            // Standard Text Handling
            if !idString.isEmpty, let uuid = UUID(uuidString: idString),
               let item = self.clipboardManager?.items.first(where: { $0.id == uuid }) {
                var updatedItem = item
                updatedItem.content = content
                updatedItem.timestamp = Date()
                updatedItem.isTrashed = false
                if let index = self.clipboardManager?.items.firstIndex(where: { $0.id == uuid }) {
                    self.clipboardManager?.items[index] = updatedItem
                    self.clipboardManager?.sortAndSave()
                }
            } else {
                self.clipboardManager?.addNewItem(content: content, type: "public.text")
            }
        }
    }
    
    private func handleBatchDelete(body: String) {
        let params = parseFormData(body)
        guard let type = params["type"], let idsString = params["ids"] else { return }
        
        let decodedIds = idsString.removingPercentEncoding ?? idsString
        let ids = decodedIds.components(separatedBy: ",")
        
        if type == "clipboard" {
            DispatchQueue.main.async {
                for idStr in ids {
                    if let uuid = UUID(uuidString: idStr),
                       let item = self.clipboardManager?.items.first(where: { $0.id == uuid }) {
                        self.clipboardManager?.moveItemToTrash(item: item)
                    }
                }
            }
        } else if type == "audio" {
            for filename in ids {
                deleteAudioFile(filename: filename)
            }
        }
    }
    
    private func deleteItem(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        DispatchQueue.main.async {
            if let item = self.clipboardManager?.items.first(where: { $0.id == uuid }) {
                self.clipboardManager?.moveItemToTrash(item: item)
            }
        }
    }
    
    private func deleteAudioFile(filename: String) {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fileURL = cacheDir.appendingPathComponent("LocalAudio").appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func parseFormData(_ body: String) -> [String: String] {
        var params = [String: String]()
        let pairs = body.components(separatedBy: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 {
                params[kv[0]] = kv[1]
            } else if kv.count == 1 {
                params[kv[0]] = ""
            }
        }
        return params
    }
    
    private func getAudioFileData(filename: String) -> Data? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = cacheDir.appendingPathComponent("LocalAudio").appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }
    
    // MARK: - Response Senders
    
    private func send(_ body: String, type: String, on connection: NWConnection) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: header.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.send(content: body.data(using: .utf8), completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }))
    }
    
    private func sendAudio(data: Data, filename: String, download: Bool, on connection: NWConnection) {
        let disposition = download ? "attachment" : "inline"
        let header = "HTTP/1.1 200 OK\r\nContent-Type: audio/x-caf\r\nContent-Disposition: \(disposition); filename=\"\(filename)\"\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: header.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }))
    }
    
    // MARK: - Localization Helper
    
    private func isChineseLanguage() -> Bool {
        guard let lang = Locale.preferredLanguages.first else { return false }
        return lang.contains("zh-Hant") || lang.contains("zh-TW") || lang.contains("zh-HK")
    }
    
    // Define dictionary of localized strings with fallback
    private func getLocalizedStrings() -> [String: String] {
        let isCN = isChineseLanguage()
        return [
            "appName": "ClippyIsle",
            "stop": isCN ? "停止" : "Stop",
            "newItem": isCN ? "新項目" : "New Item",
            "clipboard": isCN ? "剪貼簿" : "Clipboard",
            "audioFiles": isCN ? "音訊檔案" : "Audio Files",
            "selectAll": isCN ? "全選" : "Select All",
            "deleteSelected": isCN ? "刪除所選" : "Delete Selected",
            "open": isCN ? "開啟" : "Open",
            "speak": isCN ? "朗讀" : "Speak",
            "edit": isCN ? "編輯" : "Edit",
            "delete": isCN ? "刪除" : "Delete",
            "download": isCN ? "下載" : "Download",
            "save": isCN ? "儲存" : "Save",
            "cancel": isCN ? "取消" : "Cancel",
            "confirmDelTitle": isCN ? "確認刪除" : "Confirm Deletion",
            "confirmDelBody": isCN ? "您確定要刪除此項目嗎？此動作無法復原。" : "Are you sure you want to delete this item? This action cannot be undone.",
            "confirmBatchTitle": isCN ? "確認批次刪除" : "Confirm Batch Delete",
            "confirmBatchBody": isCN ? "您確定要刪除" : "Are you sure you want to delete",
            "items": isCN ? "個項目？" : "items?",
            "deleteAll": isCN ? "全部刪除" : "Delete All",
            // Removed "Paste Images" text from placeholder
            "editPlaceholder": isCN ? "在此輸入或貼上內容... (拖放 .txt / .epub 檔案)" : "Type or paste content here... (Drag & Drop .txt / .epub files)",
            "editTitle": isCN ? "編輯項目" : "Edit Item",
            "newTitle": isCN ? "新項目" : "New Item"
        ]
    }
    
    // MARK: - Theme Helpers
    private func getHexForThemeName(_ name: String) -> String {
        switch name {
        case "blue": return "#007AFF"
        case "green": return "#34C759"
        case "orange": return "#FF9500"
        case "red": return "#FF3B30"
        case "pink": return "#FF2D55"
        case "purple": return "#AF52DE"
        case "black": return "#000000"
        case "white": return "#8E8E93"
        case "retro": return "#4CD964"
        default: return "#007AFF"
        }
    }

    // MARK: - HTML Generators
    
    private func cssStyles() -> String {
        let defaults = UserDefaults.standard
        let themeName = defaults.string(forKey: "themeColorName") ?? "blue"
        let appearanceRaw = defaults.string(forKey: "appearanceMode") ?? "system"
        
        var primaryHex = "#007AFF"
        if themeName == "custom" {
            let r = defaults.double(forKey: "customColorRed")
            let g = defaults.double(forKey: "customColorGreen")
            let b = defaults.double(forKey: "customColorBlue")
            primaryHex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        } else {
            primaryHex = getHexForThemeName(themeName)
        }
        
        var isDarkMode = false
        if appearanceRaw == "dark" { isDarkMode = true }
        else if appearanceRaw == "light" { isDarkMode = false }
        else {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                isDarkMode = (window.traitCollection.userInterfaceStyle == .dark)
            }
        }
        
        let bgHex = isDarkMode ? "#000000" : "#F2F2F7"
        let cardBgHex = isDarkMode ? "#1C1C1E" : "#FFFFFF"
        let textHex = isDarkMode ? "#FFFFFF" : "#000000"
        let secondaryTextHex = isDarkMode ? "#8E8E93" : "#8E8E93"
        let borderHex = isDarkMode ? "#38383A" : "#E5E5EA"
        let btnSecBg = isDarkMode ? "rgba(142, 142, 147, 0.25)" : "rgba(142, 142, 147, 0.12)"
        let btnDangerBg = isDarkMode ? "rgba(255, 59, 48, 0.25)" : "rgba(255, 59, 48, 0.12)"
        let headerBg = isDarkMode ? "rgba(0,0,0,0.8)" : "rgba(242,242,247,0.8)"
        
        return """
        :root {
            --primary: \(primaryHex);
            --bg: \(bgHex);
            --card-bg: \(cardBgHex);
            --text: \(textHex);
            --secondary-text: \(secondaryTextHex);
            --border: \(borderHex);
            --danger: #FF3B30;
            --btn-sec-bg: \(btnSecBg);
            --btn-danger-bg: \(btnDangerBg);
            --header-bg: \(headerBg);
        }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: var(--bg); color: var(--text); margin: 0; padding: 0; line-height: 1.5; transition: background-color 0.3s, color 0.3s; }
        body.edit-mode { height: 100vh; overflow: hidden; }
        body.edit-mode .container { height: 100%; display: flex; flex-direction: column; padding-bottom: 20px; box-sizing: border-box; }
        body.edit-mode .editor-container { flex: 1; display: flex; flex-direction: column; margin-top: 0; overflow: hidden; }
        body.edit-mode form { flex: 1; display: flex; flex-direction: column; height: 100%; }
        body.edit-mode textarea { flex: 1; height: 100%; resize: none; }
        .container { max-width: 800px; margin: 0 auto; padding: 0 20px 40px 20px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; padding: 15px 0; position: sticky; top: 0; background-color: var(--header-bg); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); z-index: 100; border-bottom: 1px solid transparent; }
        h1 { margin: 0; font-size: 24px; font-weight: 700; color: var(--primary); }
        .section-header { display: flex; justify-content: space-between; align-items: center; margin: 30px 0 10px 0; }
        h2 { font-size: 13px; text-transform: uppercase; color: var(--secondary-text); margin: 0 0 0 10px; letter-spacing: 0.5px; }
        .card-list { background: var(--card-bg); border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
        .item { display: flex; padding: 16px; border-bottom: 1px solid var(--border); align-items: center; transition: background 0.2s; position: relative; }
        .item:last-child { border-bottom: none; }
        .item:hover { background-color: rgba(128,128,128,0.05); }
        .item.pinned::after { content: ''; position: absolute; top: 0; right: 0; width: 0; height: 0; border-style: solid; border-width: 0 12px 12px 0; border-color: transparent #FF3B30 transparent transparent; }
        .content { flex: 1; min-width: 0; padding-right: 15px; display: flex; align-items: center; gap: 10px; }
        .text-preview { font-size: 16px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500; }
        .meta { font-size: 13px; color: var(--secondary-text); margin-top: 4px; }
        .actions { display: flex; gap: 8px; align-items: center; }
        .btn { text-decoration: none; padding: 6px 12px; border-radius: 6px; font-size: 14px; font-weight: 600; cursor: pointer; border: none; transition: opacity 0.2s; display: inline-flex; align-items: center; justify-content: center; }
        .btn:hover { opacity: 0.8; }
        .btn-primary { background-color: var(--primary); color: white; }
        .btn-secondary { background-color: var(--btn-sec-bg); color: var(--primary); }
        .btn-danger { background-color: var(--btn-danger-bg); color: var(--danger); }
        .btn-warning { background-color: #FF9500; color: white; }
        .btn-sm { font-size: 12px; padding: 4px 8px; }
        .editor-container { background: var(--card-bg); border-radius: 12px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); margin-top: 20px; }
        textarea { width: 100%; min-height: 300px; border: 1px solid var(--border); border-radius: 8px; padding: 12px; font-size: 16px; background: transparent; color: var(--text); box-sizing: border-box; resize: vertical; font-family: monospace; transition: all 0.2s; }
        textarea:focus { outline: 2px solid var(--primary); border-color: transparent; }
        textarea.dragging { border: 2px dashed var(--primary); background-color: rgba(0, 122, 255, 0.1); }
        .form-actions { margin-top: 20px; display: flex; gap: 10px; }
        .btn-block { flex: 1; padding: 12px; font-size: 16px; }
        audio { height: 32px; width: 180px; max-width: 100%; }
        .modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; display: none; align-items: center; justify-content: center; backdrop-filter: blur(2px); }
        .modal { background: var(--card-bg); padding: 20px; border-radius: 14px; width: 300px; max-width: 90%; box-shadow: 0 10px 30px rgba(0,0,0,0.2); text-align: center; }
        .modal h3 { margin: 0 0 10px 0; color: var(--text); }
        .modal p { color: var(--secondary-text); margin-bottom: 20px; font-size: 14px; }
        .modal-actions { display: flex; gap: 10px; justify-content: center; }
        .modal-actions .btn { flex: 1; }
        .checkbox-wrapper { position: relative; width: 20px; height: 20px; display: inline-block; }
        input[type="checkbox"] { appearance: none; width: 20px; height: 20px; border: 2px solid var(--border); border-radius: 50%; outline: none; cursor: pointer; transition: all 0.2s; }
        input[type="checkbox"]:checked { background-color: var(--primary); border-color: var(--primary); }
        input[type="checkbox"]:checked::after { content: ''; position: absolute; top: 4px; left: 7px; width: 4px; height: 8px; border: solid white; border-width: 0 2px 2px 0; transform: rotate(45deg); }
        """
    }
    
    private func generateIndexHTML() -> String {
        guard let manager = clipboardManager else { return "<h1>Unavailable</h1>" }
        
        let loc = getLocalizedStrings()
        var html = baseHTMLHeader(title: loc["appName"]!, loc: loc)
        
        // --- HEADER ---
        html += """
        <div class="container">
            <div class="header">
                <h1>\(loc["appName"]!)</h1>
                <div style="display:flex; gap: 10px;">
                    <button onclick="stopSpeaking()" class="btn btn-warning">\(loc["stop"]!)</button>
                    <a href="/new" class="btn btn-primary">\(loc["newItem"]!)</a>
                </div>
            </div>
        """
        
        // --- CLIPBOARD SECTION ---
        let sortedItems = manager.items
            .filter { !$0.isTrashed }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.timestamp > $1.timestamp
            }
        
        html += """
            <div class="section-header">
                <h2>\(loc["clipboard"]!)</h2>
                <div class="actions">
                    <button onclick="toggleSelectAll('clipboard')" class="btn btn-secondary btn-sm">\(loc["selectAll"]!)</button>
                    <button onclick="batchDelete('clipboard')" class="btn btn-danger btn-sm">\(loc["deleteSelected"]!)</button>
                </div>
            </div>
            <div class="card-list" id="list-clipboard">
        """
        
        for item in sortedItems.prefix(500) {
            let display = item.displayName ?? String(item.content.prefix(60))
            let encodedContent = item.content.replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "\n", with: " ")
            let isLink = item.content.lowercased().hasPrefix("http")
            let pinnedClass = item.isPinned ? "pinned" : ""
            let id = item.id.uuidString
            
            html += """
            <div class="item \(pinnedClass)">
                <div class="content">
                    <div class="checkbox-wrapper">
                        <input type="checkbox" class="cb-clipboard" value="\(id)">
                    </div>
                    <div style="flex:1; min-width:0;">
                        <div class="text-preview">\(display)</div>
                        <div class="meta">\(item.timestamp.formatted(date: .abbreviated, time: .shortened))</div>
                    </div>
                </div>
                <div class="actions">
                    \(isLink ? "<a href=\"\(item.content)\" target=\"_blank\" class=\"btn btn-secondary\">\(loc["open"]!)</a>" : "")
                    <button onclick="speakText(this)" data-text="\(encodedContent)" class="btn btn-secondary">\(loc["speak"]!)</button>
                    <a href="/edit/\(id)" class="btn btn-secondary">\(loc["edit"]!)</a>
                    <button onclick="confirmDelete('/delete/\(id)')" class="btn btn-danger">\(loc["delete"]!)</button>
                </div>
            </div>
            """
        }
        html += "</div>"
        
        // --- AUDIO SECTION ---
        html += """
            <div class="section-header">
                <h2>\(loc["audioFiles"]!)</h2>
                <div class="actions">
                    <button onclick="toggleSelectAll('audio')" class="btn btn-secondary btn-sm">\(loc["selectAll"]!)</button>
                    <button onclick="batchDelete('audio')" class="btn btn-danger btn-sm">\(loc["deleteSelected"]!)</button>
                </div>
            </div>
            <div class="card-list" id="list-audio">
        """
        
        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let folder = cacheDir.appendingPathComponent("LocalAudio")
            if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) {
                let sortedFiles = files.sorted {
                    let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
                
                for file in sortedFiles where file.pathExtension == "caf" {
                    let filename = file.lastPathComponent
                    
                    var displayTitle = filename
                    let uuidString = filename.components(separatedBy: ".").first?.components(separatedBy: "_").first ?? ""
                    if let uuid = UUID(uuidString: uuidString),
                       let item = manager.items.first(where: { $0.id == uuid }) {
                        displayTitle = item.displayName ?? String(item.content.prefix(50))
                    } else {
                        displayTitle = "Audio: \(filename)"
                    }
                    
                    html += """
                    <div class="item">
                        <div class="content">
                            <div class="checkbox-wrapper">
                                <input type="checkbox" class="cb-audio" value="\(filename)">
                            </div>
                            <div class="text-preview">\(displayTitle)</div>
                        </div>
                        <div class="actions">
                            <audio controls preload="none" src="/audio/\(filename)"></audio>
                            <a href="/download-audio/\(filename)" class="btn btn-secondary">\(loc["download"]!)</a>
                            <button onclick="confirmDelete('/delete-audio/\(filename)')" class="btn btn-danger">\(loc["delete"]!)</button>
                        </div>
                    </div>
                    """
                }
            }
        }
        
        html += """
            </div>
        </div>
        
        <!-- Custom Confirmation Modal -->
        <div id="confirmModal" class="modal-overlay">
            <div class="modal">
                <h3>\(loc["confirmDelTitle"]!)</h3>
                <p>\(loc["confirmDelBody"]!)</p>
                <div class="modal-actions">
                    <button onclick="closeModal()" class="btn btn-secondary">\(loc["cancel"]!)</button>
                    <a id="confirmBtn" href="#" class="btn btn-danger">\(loc["delete"]!)</a>
                </div>
            </div>
        </div>
        
        <!-- Custom Batch Delete Modal -->
        <div id="batchModal" class="modal-overlay">
            <div class="modal">
                <h3>\(loc["confirmBatchTitle"]!)</h3>
                <p>\(loc["confirmBatchBody"]!) <span id="batchCount">0</span> \(loc["items"]!)</p>
                <div class="modal-actions">
                    <button onclick="closeBatchModal()" class="btn btn-secondary">\(loc["cancel"]!)</button>
                    <button onclick="performBatchDelete()" class="btn btn-danger">\(loc["deleteAll"]!)</button>
                </div>
            </div>
        </div>
        
        <form id="batchForm" action="/api/batch-delete" method="POST" style="display:none;">
            <input type="hidden" name="type" id="batchType">
            <input type="hidden" name="ids" id="batchIds">
        </form>
        
        <script>
            // Single Delete Modal Logic
            function confirmDelete(url) {
                document.getElementById('confirmBtn').href = url;
                document.getElementById('confirmModal').style.display = 'flex';
            }
            function closeModal() {
                document.getElementById('confirmModal').style.display = 'none';
            }
            
            // Batch Selection Logic
            function toggleSelectAll(type) {
                const checkboxes = document.querySelectorAll('.cb-' + type);
                const first = checkboxes[0];
                if(!first) return;
                const newState = !first.checked;
                checkboxes.forEach(cb => cb.checked = newState);
            }
            
            // Batch Delete Logic
            let currentBatchType = '';
            
            function batchDelete(type) {
                const checkboxes = document.querySelectorAll('.cb-' + type + ':checked');
                if (checkboxes.length === 0) return;
                
                currentBatchType = type;
                document.getElementById('batchCount').innerText = checkboxes.length;
                document.getElementById('batchModal').style.display = 'flex';
            }
            
            function closeBatchModal() {
                document.getElementById('batchModal').style.display = 'none';
            }
            
            function performBatchDelete() {
                const checkboxes = document.querySelectorAll('.cb-' + currentBatchType + ':checked');
                const ids = Array.from(checkboxes).map(cb => cb.value).join(',');
                
                document.getElementById('batchType').value = currentBatchType;
                document.getElementById('batchIds').value = ids;
                document.getElementById('batchForm').submit();
            }
        </script>
        </body></html>
        """
        return html
    }
    
    private func generateEditHTML(id: String?) -> String {
        var content = ""
        var idValue = ""
        let loc = getLocalizedStrings()
        var title = loc["newTitle"]!
        
        if let id = id, let uuid = UUID(uuidString: id),
           let item = clipboardManager?.items.first(where: { $0.id == uuid }) {
            content = item.content
            title = loc["editTitle"]!
            idValue = id
        }
        
        var html = baseHTMLHeader(title: title, loc: loc)
        html += """
        <div class="container">
            <div class="header">
                <h1>\(title)</h1>
            </div>
            <div class="editor-container">
                <form action="/save" method="POST">
                    <input type="hidden" name="id" value="\(idValue)">
                    <textarea id="contentArea" name="content" placeholder="\(loc["editPlaceholder"]!)" required>\(content)</textarea>
                    <div class="form-actions">
                        <a href="/" class="btn btn-secondary btn-block" style="text-align:center">\(loc["cancel"]!)</a>
                        <button type="submit" class="btn btn-primary btn-block">\(loc["save"]!)</button>
                    </div>
                </form>
            </div>
        </div>
        <script>document.body.classList.add('edit-mode');</script>
        </body></html>
        """
        return html
    }
    
    private func baseHTMLHeader(title: String, loc: [String:String]) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <link rel="stylesheet" href="/style.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
            <script>
                function speakText(btn) {
                    let text = btn.getAttribute('data-text');
                    if ('speechSynthesis' in window) {
                        window.speechSynthesis.cancel();
                        let utterance = new SpeechSynthesisUtterance(text);
                        window.speechSynthesis.speak(utterance);
                    } else {
                        alert("TTS not supported.");
                    }
                }
                
                function stopSpeaking() {
                    if ('speechSynthesis' in window) {
                        window.speechSynthesis.cancel();
                    }
                }
                
                document.addEventListener('DOMContentLoaded', () => {
                    const textarea = document.querySelector('textarea');
                    if (textarea) {
                        // Drag & Drop Logic
                        textarea.addEventListener('dragover', (e) => {
                            e.preventDefault(); e.stopPropagation();
                            textarea.classList.add('dragging');
                        });
                        textarea.addEventListener('dragleave', (e) => {
                            e.preventDefault(); e.stopPropagation();
                            textarea.classList.remove('dragging');
                        });
                        textarea.addEventListener('drop', (e) => {
                            e.preventDefault(); e.stopPropagation();
                            textarea.classList.remove('dragging');
                            
                            if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
                                const file = e.dataTransfer.files[0];
                                
                                // EPUB Handling
                                if (file.name.toLowerCase().endsWith('.epub')) {
                                    if (typeof JSZip === 'undefined') {
                                        alert("JSZip library not loaded. Cannot parse EPUB.");
                                        return;
                                    }
                                    textarea.value = "Parsing EPUB, please wait...";
                                    
                                    JSZip.loadAsync(file).then(async (zip) => {
                                        try {
                                            const container = await zip.file("META-INF/container.xml").async("string");
                                            const parser = new DOMParser();
                                            const rootMatch = container.match(/full-path="([^"]+)"/);
                                            if (!rootMatch) throw new Error("No rootfile found");
                                            const rootPath = rootMatch[1];
                                            const opfContent = await zip.file(rootPath).async("string");
                                            const itemRefRegex = /<[^:]*:?itemref[^>]+idref="([^"]+)"/g;
                                            let match;
                                            const spineIds = [];
                                            while ((match = itemRefRegex.exec(opfContent)) !== null) { spineIds.push(match[1]); }
                                            const itemRegex = /<[^:]*:?item[^>]+id="([^"]+)"[^>]+href="([^"]+)"/g;
                                            const manifestMap = {};
                                            while ((match = itemRegex.exec(opfContent)) !== null) { manifestMap[match[1]] = match[2]; }
                                            let fullText = "";
                                            const basePath = rootPath.substring(0, rootPath.lastIndexOf("/") + 1);
                                            for (const id of spineIds) {
                                                const href = manifestMap[id];
                                                if (href) {
                                                    let targetPath = basePath + href;
                                                    while(targetPath.includes("/../")) { targetPath = targetPath.replace(/[^\\/]+\\/\\.\\.\\//, ""); }
                                                    if (targetPath.startsWith("./")) targetPath = targetPath.substring(2);
                                                    let fileData = await zip.file(targetPath)?.async("string");
                                                    if (!fileData) fileData = await zip.file(href)?.async("string");
                                                    if (fileData) {
                                                        const htmlDoc = parser.parseFromString(fileData, "text/html");
                                                        htmlDoc.querySelectorAll('script, style').forEach(el => el.remove());
                                                        const text = htmlDoc.body ? htmlDoc.body.innerText : "";
                                                        if (text.trim().length > 0) { fullText += text + "\\n\\n------------------\\n\\n"; }
                                                    }
                                                }
                                            }
                                            textarea.value = fullText.length === 0 ? "Parsed EPUB but found no text." : fullText;
                                        } catch (err) {
                                            textarea.value = "Error parsing EPUB: " + err.message;
                                        }
                                    });
                                    return;
                                }
                                
                                // Text File Handling
                                const reader = new FileReader();
                                reader.onload = (ev) => {
                                    const buffer = ev.target.result;
                                    let text = "";
                                    try { text = new TextDecoder("utf-8", { fatal: true }).decode(buffer); }
                                    catch (e) {
                                        try { text = new TextDecoder("big5", { fatal: true }).decode(buffer); }
                                        catch (e2) {
                                            try { text = new TextDecoder("gbk", { fatal: true }).decode(buffer); }
                                            catch (e3) { text = new TextDecoder("utf-8").decode(buffer); }
                                        }
                                    }
                                    textarea.value = text;
                                };
                                reader.readAsArrayBuffer(file);
                            }
                        });
                    }
                });
            </script>
        </head>
        <body>
        """
    }
    
    // MARK: - Network Helper
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}