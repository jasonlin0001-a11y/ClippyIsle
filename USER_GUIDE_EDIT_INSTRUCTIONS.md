# 使用說明編輯指南 / User Guide Edit Instructions

## 中文說明

### 如何編輯使用說明的標題或內文

使用說明項目是一個內建的特殊項目，永遠顯示在列表最上方。如果您想要修改使用說明的標題或內容，請按照以下步驟操作：

#### 編輯位置

檔案路徑：`ClippyIsle/Managers/ClipboardManager.swift`

在此檔案中尋找 `ensureUserGuideExists()` 函數（大約在第 72-159 行）。

#### 修改標題

在 `ensureUserGuideExists()` 函數的最後部分，找到以下程式碼：

```swift
let guideItem = ClipboardItem(
    id: userGuideItemID,
    content: guideContent,
    type: UTType.text.identifier,
    filename: nil,
    timestamp: Date(),
    isPinned: true,
    displayName: "CC Isle 使用說明",  // <-- 在這裡修改標題
    isTrashed: false,
    tags: nil,
    fileData: nil
)
```

修改 `displayName` 的值即可更改顯示的標題。

#### 修改內文

在同一個函數中，找到 `guideContent` 變數的定義（大約在第 77 行開始）：

```swift
let guideContent = """
# CC Isle 使用說明

歡迎使用 CC Isle（ClippyIsle）！這是一個功能強大的剪貼簿管理工具。

... (後續內容)
"""
```

在三引號 `"""` 之間的所有文字都是使用說明的內容。您可以：
- 修改任何文字內容
- 新增或刪除章節
- 調整格式（支援 Markdown 格式）

#### 儲存與生效

修改完成後：
1. 儲存檔案
2. 重新編譯並執行 App
3. 使用說明的內容會自動更新

**注意**：如果使用者已經有舊版本的使用說明項目，當 App 啟動時會自動更新為新版本的內容。

---

## English Instructions

### How to Edit the User Guide Title or Content

The user guide is a built-in special item that always appears at the top of the list. If you want to modify the title or content of the user guide, follow these steps:

#### Edit Location

File path: `ClippyIsle/Managers/ClipboardManager.swift`

In this file, find the `ensureUserGuideExists()` function (approximately lines 72-159).

#### Modify the Title

In the `ensureUserGuideExists()` function, near the end, find this code:

```swift
let guideItem = ClipboardItem(
    id: userGuideItemID,
    content: guideContent,
    type: UTType.text.identifier,
    filename: nil,
    timestamp: Date(),
    isPinned: true,
    displayName: "CC Isle 使用說明",  // <-- Change the title here
    isTrashed: false,
    tags: nil,
    fileData: nil
)
```

Modify the `displayName` value to change the displayed title.

#### Modify the Content

In the same function, find the `guideContent` variable definition (starting around line 77):

```swift
let guideContent = """
# CC Isle 使用說明

歡迎使用 CC Isle（ClippyIsle）！這是一個功能強大的剪貼簿管理工具。

... (content continues)
"""
```

All text between the triple quotes `"""` is the user guide content. You can:
- Modify any text content
- Add or remove sections
- Adjust formatting (Markdown format is supported)

#### Save and Apply

After making changes:
1. Save the file
2. Rebuild and run the app
3. The user guide content will be automatically updated

**Note**: If users already have an old version of the user guide item, it will be automatically updated to the new version when the app launches.

---

## 技術細節 / Technical Details

### 相關檔案 / Related Files

1. **SharedModels/SharedModels.swift**
   - 定義了 `userGuideItemID` 常數
   - Defines the `userGuideItemID` constant

2. **ClippyIsle/Managers/ClipboardManager.swift**
   - `ensureUserGuideExists()` 函數：建立和更新使用說明
   - `ensureUserGuideExists()` function: Creates and updates the user guide
   - `sortAndSave()` 函數：確保使用說明永遠在最上方
   - `sortAndSave()` function: Ensures the user guide is always at the top
   - `moveItemToTrash()` 和 `permanentlyDeleteItem()` 函數：限制免費版用戶刪除使用說明
   - `moveItemToTrash()` and `permanentlyDeleteItem()` functions: Restrict free users from deleting the guide

3. **ClippyIsle/ContentView.swift**
   - 刪除動作的 UI 處理，包含升級提示
   - UI handling for delete action, including upgrade prompt

### 特殊 UUID

使用說明項目使用固定的 UUID：`00000000-0000-0000-0000-000000000001`

這確保了該項目在所有裝置上都是唯一且一致的。

The user guide uses a fixed UUID: `00000000-0000-0000-0000-000000000001`

This ensures the item is unique and consistent across all devices.
