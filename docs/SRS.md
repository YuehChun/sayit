# Typeless — 軟體需求規格書 (SRS)

> **Software Requirements Specification**
> **版本**：1.0.0
> **日期**：2026-02-12
> **平台**：macOS
> **狀態**：Draft

---

## 1. 專案概述

### 1.1 產品定位

Typeless 是一個基於 AI 的**智慧語音輸入與編輯平台**，運行於 macOS。核心定位是讓語音輸入不再只是「聽寫」，而是透過 AI 即時理解，將口語內容轉化為**高品質、排版工整且可直接使用**的文字。

### 1.2 核心架構

語音處理採用**兩階段 AI Pipeline**：

```
麥克風音訊 → [Gemini API: 語音轉文字] → 原始文字 → [Claude Sonnet 4.5: 文字修正] → 最終輸出
```

| 階段 | 負責 API | 用途 |
|------|---------|------|
| Stage 1: STT | Google Gemini API | 語音辨識、多語言轉錄 |
| Stage 2: Refinement | Anthropic Claude Sonnet 4.5 | 去除贅字、修正改口、格式化、語氣調整 |

### 1.3 技術選型摘要

| 項目 | 技術 |
|------|------|
| 平台 | macOS (Swift / SwiftUI) |
| 語音轉文字 | Google Gemini API (multimodal audio) |
| 文字修正 | Anthropic Claude Sonnet 4.5 API |
| 系統整合 | macOS Accessibility API, CGEvent |
| 音訊擷取 | AVFoundation / AVAudioEngine |
| 資料儲存 | 本地 SQLite + UserDefaults |
| 網路通訊 | URLSession / async-await |

### 1.4 API 金鑰管理

使用者需自行提供：
- **Gemini API Key**：用於語音轉文字
- **Anthropic API Key**：用於文字修正 (Claude Sonnet 4.5)

金鑰儲存於 macOS Keychain，不以明文存放。

---

## 2. 使用者角色

| 角色 | 描述 |
|------|------|
| 一般使用者 | 使用語音輸入功能進行日常文字工作 |
| 進階使用者 | 使用語音指令編輯、自訂詞典、調整語氣風格 |

---

## 3. 功能需求 (Functional Requirements)

### 3.1 智慧語音輸入 (Smart AI Dictation)

#### FR-3.1.1 語音擷取

| 項目 | 規格 |
|------|------|
| ID | FR-3.1.1 |
| 名稱 | 即時語音擷取 |
| 描述 | 透過 macOS 麥克風即時擷取使用者語音 |
| 觸發方式 | 使用者按下全域快捷鍵 (預設: `Fn` 鍵，可自訂) |
| 輸入 | 麥克風音訊串流 |
| 處理 | 使用 AVAudioEngine 擷取 PCM 音訊，以串流方式送至 Gemini API |
| 輸出 | 原始轉錄文字 |
| 驗收標準 | 1. 按下快捷鍵後 500ms 內開始錄音<br>2. 放開快捷鍵後停止錄音並送出辨識<br>3. 支援 Push-to-Talk 與 Toggle 兩種模式 |

#### FR-3.1.2 語音轉文字 (STT)

| 項目 | 規格 |
|------|------|
| ID | FR-3.1.2 |
| 名稱 | Gemini 語音轉文字 |
| 描述 | 將擷取的音訊透過 Gemini API 轉換為文字 |
| API | Google Gemini API (multimodal audio input) |
| 支援格式 | PCM 16-bit, 16kHz mono |
| 延遲目標 | 首字延遲 < 1 秒 (串流模式) |
| 驗收標準 | 1. 中文辨識準確率 > 95%<br>2. 英文辨識準確率 > 95%<br>3. 中英混語辨識準確率 > 90%<br>4. 支援超過 100 種語言 |

#### FR-3.1.3 AI 文字修正

| 項目 | 規格 |
|------|------|
| ID | FR-3.1.3 |
| 名稱 | Claude Sonnet 4.5 文字修正 |
| 描述 | 將 Gemini 轉錄的原始文字，送至 Claude Sonnet 4.5 進行修正 |
| API | Anthropic Claude Sonnet 4.5 (`claude-sonnet-4-5-20250929`) |
| 處理項目 | 見下方子項目 |
| 延遲目標 | 修正完成 < 2 秒 |

**修正子項目**：

| 子項目 | 說明 | 範例 |
|--------|------|------|
| 去除填充詞 | 刪除「呃」「嗯」「那個」「就是說」等 | 「呃，我想要，嗯，買杯咖啡」→「我想要買杯咖啡」 |
| 修正改口 | 偵測改口並只保留最終意思 | 「明天七點...喔不，改三點」→「明天三點」 |
| 去除重複 | 刪除不必要的重複詞彙 | 「我要我要去買東西」→「我要去買東西」 |
| 標點修正 | 自動加入正確標點符號 | 口語轉為書面語標點 |
| 語句通順 | 調整口語為通順的書面表達 | 保持原意，但語句更流暢 |

**Claude Sonnet 4.5 System Prompt 設計**：

```
你是一個專業的語音轉文字修正助手。你的任務是將語音辨識的原始輸出修正為乾淨、通順的書面文字。

規則：
1. 刪除所有填充詞（呃、嗯、那個、就是說、然後、對、嘛）
2. 偵測改口並只保留最終意圖
3. 刪除不必要的重複
4. 加入正確的標點符號
5. 將口語調整為通順的書面語
6. 保持原始語意不變，不添加任何內容
7. 如果內容包含清單，自動格式化為條列式
8. 保留專有名詞原樣
9. 中英混語時保持自然的混語方式

僅輸出修正後的文字，不要加任何解釋。
```

#### FR-3.1.4 多語言支援

| 項目 | 規格 |
|------|------|
| ID | FR-3.1.4 |
| 名稱 | 多語言與混語支援 |
| 描述 | 支援多語言辨識，特別是中英文混語 |
| 主要語言 | 繁體中文、English |
| 混語支援 | 中英文混雜（晶晶體）精準辨識 |
| 語言設定 | 使用者可設定主要語言與次要語言 |
| 驗收標準 | 1. 單語辨識準確率 > 95%<br>2. 混語辨識準確率 > 90% |

#### FR-3.1.5 個人詞典

| 項目 | 規格 |
|------|------|
| ID | FR-3.1.5 |
| 名稱 | 個人詞典管理 |
| 描述 | 使用者可自行添加專有名詞、術語、姓名 |
| 功能 | 1. 新增/編輯/刪除詞彙<br>2. 詞彙分類管理<br>3. 匯入/匯出詞典 |
| 實作方式 | 將個人詞典注入 Claude Sonnet 4.5 的修正 prompt 中 |
| 儲存 | 本地 SQLite 資料庫 |
| 驗收標準 | 1. 加入詞典後的辨識準確率提升至 > 98%<br>2. 詞典容量支援 > 10,000 詞 |

---

### 3.2 即時 AI 編輯與改寫 (Speak to Edit)

#### FR-3.2.1 指令化修改

| 項目 | 規格 |
|------|------|
| ID | FR-3.2.1 |
| 名稱 | 語音指令編輯 |
| 描述 | 選取文字後，以語音指令進行修改 |
| 操作流程 | 1. 使用者在任意 App 選取文字<br>2. 按下編輯快捷鍵 (預設: `⌘ + Shift + V`)<br>3. 說出編輯指令<br>4. Claude Sonnet 4.5 依指令修改文字<br>5. 修改後文字替換原選取內容 |
| 支援指令範例 | - 「改得正式一點」<br>- 「翻譯成日文」<br>- 「縮短長度」<br>- 「改成條列式」<br>- 「修正文法」 |
| 驗收標準 | 1. 指令理解準確率 > 95%<br>2. 修改結果符合使用者意圖<br>3. 3 秒內完成修改 |

**Claude Sonnet 4.5 Edit Prompt 設計**：

```
你是一個文字編輯助手。使用者會提供一段原始文字和一個編輯指令。
請根據指令修改文字。

原始文字：
{selected_text}

編輯指令：
{voice_command}

規則：
1. 只依照指令修改，不做額外變更
2. 保持原始文字的核心語意
3. 僅輸出修改後的文字，不加解釋
```

#### FR-3.2.2 語氣與風格調整

| 項目 | 規格 |
|------|------|
| ID | FR-3.2.2 |
| 名稱 | 語氣風格調整 |
| 描述 | 根據使用者需求調整文字的語氣與風格 |
| 預設風格 | 專業、幽默、簡潔、詳細、友善、正式 |
| 自訂風格 | 使用者可自訂風格 prompt |
| 驗收標準 | 風格轉換後文字自然且符合目標語氣 |

#### FR-3.2.3 App 語境適應

| 項目 | 規格 |
|------|------|
| ID | FR-3.2.3 |
| 名稱 | 應用程式語境偵測 |
| 描述 | 偵測目前使用的 App，自動調整輸出語氣 |
| 偵測方式 | 透過 macOS Accessibility API 取得前景 App 資訊 |
| 預設語境 | - Slack/Discord → 輕鬆口語<br>- Gmail/Outlook → 正式信件<br>- Notion/Notes → 筆記體<br>- VS Code/Terminal → 技術描述 |
| 可覆蓋 | 使用者可關閉或自訂各 App 的語境設定 |
| 驗收標準 | 1. 正確偵測前景 App<br>2. 語氣調整符合 App 情境 |

---

### 3.3 自動格式化與結構化 (Auto-Formatting)

#### FR-3.3.1 智慧排版

| 項目 | 規格 |
|------|------|
| ID | FR-3.3.1 |
| 名稱 | 自動格式化 |
| 描述 | 偵測內容結構，自動轉換為適當格式 |
| 支援格式 | - 條列式 (Bullet points / Numbered list)<br>- 標題層級<br>- 段落分隔 |
| 實作方式 | 在 Claude Sonnet 4.5 修正階段偵測並格式化 |
| 驗收標準 | 1. 清單內容自動轉為條列式<br>2. 格式化準確率 > 90% |

#### FR-3.3.2 Markdown 支援

| 項目 | 規格 |
|------|------|
| ID | FR-3.3.2 |
| 名稱 | Markdown 輸出 |
| 描述 | 支援以 Markdown 語法輸出 |
| 支援語法 | 標題 (#)、清單 (- / 1.)、粗體 (**)、斜體 (*)、程式碼區塊 |
| 設定 | 使用者可開關 Markdown 模式 |
| 驗收標準 | 輸出的 Markdown 語法正確且可被主流編輯器解析 |

---

### 3.4 系統整合 (System Integration)

#### FR-3.4.1 全域快捷鍵

| 項目 | 規格 |
|------|------|
| ID | FR-3.4.1 |
| 名稱 | 全域快捷鍵系統 |
| 描述 | 在 macOS 任何位置均可啟動語音輸入 |
| 預設快捷鍵 | - 語音輸入: `Fn` (長按)<br>- 語音編輯: `⌘ + Shift + V`<br>- 開關 App: `⌘ + Shift + T` |
| 自訂 | 所有快捷鍵均可自訂 |
| 實作 | CGEvent tap / NSEvent.addGlobalMonitorForEvents |
| 驗收標準 | 1. 快捷鍵不與其他 App 衝突<br>2. 回應延遲 < 100ms |

#### FR-3.4.2 全域文字輸入

| 項目 | 規格 |
|------|------|
| ID | FR-3.4.2 |
| 名稱 | 跨應用程式文字插入 |
| 描述 | 在任意有文字輸入框的 App 中插入修正後的文字 |
| 實作方式 | 透過 macOS Accessibility API 或 CGEvent 模擬鍵盤輸入 |
| 相容 App | 所有支援標準文字輸入的 macOS App |
| 驗收標準 | 1. 文字正確插入目標 App<br>2. 支援 Unicode 與 CJK 字元<br>3. 不破壞目標 App 的既有內容 |

#### FR-3.4.3 浮動視窗 (Floating Panel)

| 項目 | 規格 |
|------|------|
| ID | FR-3.4.3 |
| 名稱 | 浮動控制面板 |
| 描述 | 類似 Typeless 的浮動視窗，顯示錄音狀態與即時轉錄 |
| 外觀 | - 小型浮動視窗，位於螢幕上方或輸入框附近<br>- 顯示錄音波形動畫<br>- 即時顯示轉錄文字<br>- 最小化/透明模式 |
| 行為 | - 錄音時自動出現<br>- 錄音結束後短暫顯示結果再自動隱藏<br>- 可拖曳移動位置 |
| 驗收標準 | 1. 視窗不阻擋使用者操作<br>2. 視窗層級始終在最上層<br>3. 動畫流暢 (60fps) |

---

### 3.5 設定與偏好 (Settings & Preferences)

#### FR-3.5.1 API 設定

| 項目 | 規格 |
|------|------|
| ID | FR-3.5.1 |
| 名稱 | API 金鑰設定 |
| 描述 | 管理 Gemini 與 Anthropic API 金鑰 |
| 欄位 | - Gemini API Key (必填)<br>- Anthropic API Key (必填) |
| 驗證 | 輸入後即時驗證 API Key 有效性 |
| 儲存 | macOS Keychain (加密) |
| 驗收標準 | 1. API Key 以密碼方式顯示<br>2. 驗證成功/失敗有明確提示<br>3. Key 不以明文儲存 |

#### FR-3.5.2 語言設定

| 項目 | 規格 |
|------|------|
| ID | FR-3.5.2 |
| 名稱 | 語言偏好設定 |
| 欄位 | - 主要語言<br>- 次要語言 (可選)<br>- 混語模式開關 |

#### FR-3.5.3 快捷鍵設定

| 項目 | 規格 |
|------|------|
| ID | FR-3.5.3 |
| 名稱 | 快捷鍵自訂 |
| 欄位 | - 語音輸入快捷鍵<br>- 語音編輯快捷鍵<br>- 應用程式開關快捷鍵 |
| 衝突偵測 | 自動偵測與其他 App 的快捷鍵衝突 |

#### FR-3.5.4 輸出設定

| 項目 | 規格 |
|------|------|
| ID | FR-3.5.4 |
| 名稱 | 輸出偏好設定 |
| 欄位 | - Markdown 模式開關<br>- 自動格式化開關<br>- 預設語氣風格<br>- App 語境自動偵測開關 |

---

### 3.6 歷史記錄 (History)

#### FR-3.6.1 輸入歷史

| 項目 | 規格 |
|------|------|
| ID | FR-3.6.1 |
| 名稱 | 輸入歷史記錄 |
| 描述 | 記錄過去的語音輸入結果 |
| 儲存內容 | - 時間戳記<br>- 原始轉錄文字<br>- 修正後文字<br>- 使用的 App 名稱 |
| 功能 | - 搜尋歷史記錄<br>- 複製歷史文字<br>- 刪除個別 / 全部記錄 |
| 儲存 | 本地 SQLite |
| 保留期限 | 預設 30 天，可自訂 |
| 驗收標準 | 1. 歷史記錄可快速搜尋<br>2. 支援批次刪除 |

---

## 4. 非功能需求 (Non-Functional Requirements)

### 4.1 效能需求

| ID | 項目 | 指標 |
|----|------|------|
| NFR-4.1.1 | 錄音啟動延遲 | < 500ms |
| NFR-4.1.2 | STT 首字延遲 | < 1 秒 |
| NFR-4.1.3 | 文字修正延遲 | < 2 秒 |
| NFR-4.1.4 | 端到端延遲 (語音→最終文字) | < 3 秒 |
| NFR-4.1.5 | App 啟動時間 | < 2 秒 |
| NFR-4.1.6 | 記憶體使用 | 閒置 < 50MB, 錄音中 < 150MB |
| NFR-4.1.7 | CPU 使用 | 閒置 < 1%, 錄音中 < 10% |

### 4.2 安全需求

| ID | 項目 | 描述 |
|----|------|------|
| NFR-4.2.1 | API Key 安全 | 使用 macOS Keychain 儲存，不以明文存放 |
| NFR-4.2.2 | 資料本地化 | 音訊不儲存，僅暫存於記憶體中處理 |
| NFR-4.2.3 | 網路傳輸 | 所有 API 呼叫使用 HTTPS/TLS 1.3 |
| NFR-4.2.4 | 隱私設計 | Private by design，不收集使用者資料 |
| NFR-4.2.5 | 歷史記錄加密 | 本地 SQLite 使用 SQLCipher 加密 |

### 4.3 可用性需求

| ID | 項目 | 描述 |
|----|------|------|
| NFR-4.3.1 | 首次設定 | 引導式設定流程，3 分鐘內完成 |
| NFR-4.3.2 | 學習成本 | 核心功能無需額外學習，按住說話即可 |
| NFR-4.3.3 | 視覺回饋 | 錄音中有明確的視覺與音效回饋 |
| NFR-4.3.4 | 錯誤處理 | API 錯誤有友善的錯誤訊息 |

### 4.4 相容性需求

| ID | 項目 | 描述 |
|----|------|------|
| NFR-4.4.1 | macOS 版本 | 支援 macOS 13 (Ventura) 及以上 |
| NFR-4.4.2 | Apple Silicon | 原生支援 Apple Silicon (M1/M2/M3/M4) |
| NFR-4.4.3 | Intel Mac | 支援 Intel Mac (Rosetta 2) |
| NFR-4.4.4 | 麥克風 | 支援內建麥克風與外接 USB / 藍牙麥克風 |

---

## 5. 系統架構

### 5.1 整體架構圖

```
┌─────────────────────────────────────────────────────────┐
│                    Typeless macOS App                     │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  UI 層   │  │ 音訊引擎 │  │ AI 管線  │  │ 系統整合 │ │
│  │ SwiftUI  │  │AVAudio   │  │ Pipeline │  │ a11y API │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │             │             │              │        │
│  ┌────┴─────────────┴─────────────┴──────────────┴────┐  │
│  │              Core Service Layer                     │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │  │
│  │  │ AudioManager│  │ AIProcessor  │  │ TextInject│  │  │
│  │  │             │  │              │  │           │  │  │
│  │  │ - capture   │  │ - geminiSTT  │  │ - paste   │  │  │
│  │  │ - stream    │  │ - claudeEdit │  │ - type    │  │  │
│  │  │ - encode    │  │ - format     │  │ - replace │  │  │
│  │  └─────────────┘  └──────────────┘  └───────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Data Layer                             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │  │
│  │  │ Keychain │  │ SQLite   │  │ UserDefaults     │  │  │
│  │  │ API Keys │  │ History  │  │ Preferences      │  │  │
│  │  │          │  │ Dictionary│  │ Shortcuts        │  │  │
│  │  └──────────┘  └──────────┘  └──────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │               │
                        ▼               ▼
              ┌─────────────┐  ┌──────────────┐
              │ Gemini API  │  │ Anthropic API│
              │ (STT)       │  │ (Refinement) │
              └─────────────┘  └──────────────┘
```

### 5.2 模組說明

#### 5.2.1 UI 層 (Presentation Layer)

| 元件 | 說明 |
|------|------|
| FloatingPanel | 浮動視窗，顯示錄音狀態與即時轉錄 |
| SettingsWindow | 設定視窗 (API Key, 語言, 快捷鍵, 偏好) |
| HistoryWindow | 歷史記錄視窗 |
| DictionaryWindow | 個人詞典管理視窗 |
| MenuBarItem | 選單列圖示與快捷選單 |
| OnboardingFlow | 首次使用引導流程 |

#### 5.2.2 音訊引擎 (Audio Engine)

| 元件 | 說明 |
|------|------|
| AudioCaptureManager | 管理麥克風權限、音訊擷取 |
| AudioStreamEncoder | 將 PCM 音訊編碼為 API 所需格式 |
| AudioLevelMonitor | 監測音量等級，供 UI 波形顯示 |

#### 5.2.3 AI 管線 (AI Pipeline)

| 元件 | 說明 |
|------|------|
| GeminiSTTService | 封裝 Gemini API 呼叫，處理串流 STT |
| ClaudeRefinementService | 封裝 Claude Sonnet 4.5 API，處理文字修正 |
| ClaudeEditService | 封裝 Claude Sonnet 4.5 API，處理語音指令編輯 |
| PromptManager | 管理各種 Prompt 模板 |
| PipelineOrchestrator | 串接 STT → Refinement 的完整流程 |

#### 5.2.4 系統整合 (System Integration)

| 元件 | 說明 |
|------|------|
| GlobalShortcutManager | 管理全域快捷鍵監聽 |
| TextInjectionService | 將文字注入目標 App 的輸入框 |
| AppContextDetector | 偵測前景 App，決定輸出語境 |
| AccessibilityBridge | 封裝 macOS Accessibility API |

#### 5.2.5 資料層 (Data Layer)

| 元件 | 說明 |
|------|------|
| KeychainManager | API Key 加密儲存/讀取 |
| HistoryStore | 歷史記錄 CRUD |
| DictionaryStore | 個人詞典 CRUD |
| PreferencesStore | 偏好設定讀寫 |

---

## 6. API 規格

### 6.1 Gemini API 呼叫規格

**用途**：語音轉文字 (STT)

```swift
// Endpoint
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent

// Request Body
{
  "contents": [{
    "parts": [
      {
        "inline_data": {
          "mime_type": "audio/wav",
          "data": "<base64_encoded_audio>"
        }
      },
      {
        "text": "請將這段音訊轉錄為文字。語言：繁體中文（可能包含英文混語）。請僅輸出轉錄文字，不加任何說明。"
      }
    ]
  }],
  "generationConfig": {
    "temperature": 0.1,
    "maxOutputTokens": 8192
  }
}
```

**錯誤處理**：

| HTTP Status | 處理方式 |
|-------------|---------|
| 400 | 檢查音訊格式，提示使用者 |
| 401 | API Key 無效，引導重新設定 |
| 429 | Rate limit，等待後重試 (exponential backoff) |
| 500 | 伺服器錯誤，提示使用者稍後重試 |

### 6.2 Anthropic Claude API 呼叫規格

**用途**：文字修正 & 語音指令編輯

```swift
// Endpoint
POST https://api.anthropic.com/v1/messages

// Headers
{
  "x-api-key": "<ANTHROPIC_API_KEY>",
  "anthropic-version": "2023-06-01",
  "content-type": "application/json"
}

// Request Body (文字修正)
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 4096,
  "system": "<refinement_system_prompt>",
  "messages": [
    {
      "role": "user",
      "content": "<raw_transcribed_text>"
    }
  ]
}

// Request Body (語音指令編輯)
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 4096,
  "system": "<edit_system_prompt>",
  "messages": [
    {
      "role": "user",
      "content": "原始文字：\n{selected_text}\n\n編輯指令：\n{voice_command}"
    }
  ]
}
```

---

## 7. UI/UX 設計規格

### 7.1 設計原則

遵循 Typeless 的設計語言：

1. **最小干擾**：浮動視窗小巧，不阻擋使用者工作
2. **即時回饋**：錄音狀態有明確的視覺與音效回饋
3. **零學習成本**：按住說話，放開送出
4. **原生體驗**：遵循 macOS Human Interface Guidelines

### 7.2 介面元件

#### 7.2.1 選單列圖示 (Menu Bar)

```
┌──────────────────────────────┐
│  ◉ Typeless                  │
│  ─────────────────────────── │
│  ▶ 開始語音輸入   (Fn)       │
│  ✏ 語音編輯      (⌘⇧V)     │
│  ─────────────────────────── │
│  📖 歷史記錄                 │
│  📚 個人詞典                 │
│  ⚙ 偏好設定...              │
│  ─────────────────────────── │
│  ⓘ 關於 Typeless            │
│  ✕ 結束                     │
└──────────────────────────────┘
```

#### 7.2.2 浮動面板 (Floating Panel)

**待機狀態**：不顯示（僅選單列圖示）

**錄音中狀態**：

```
┌──────────────────────────────────┐
│  🎙 正在聆聽...                   │
│  ▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁  (波形動畫)  │
│                                   │
│  我想要預訂明天下午三點的會議室... │
│  (即時轉錄文字，持續更新)         │
└──────────────────────────────────┘
```

**修正中狀態**：

```
┌──────────────────────────────────┐
│  ⟳ 修正中...                     │
│  ████████░░░░  (進度指示)        │
└──────────────────────────────────┘
```

**完成狀態** (短暫顯示後自動隱藏)：

```
┌──────────────────────────────────┐
│  ✓ 已輸入                        │
│  我想要預訂明天下午三點的會議室。 │
└──────────────────────────────────┘
```

#### 7.2.3 設定視窗 (Settings Window)

```
┌─────────────────────────────────────────────┐
│  Typeless 偏好設定                    ✕     │
│  ─────────────────────────────────────────── │
│  [一般] [API] [語言] [快捷鍵] [進階]        │
│                                              │
│  ┌─ API 設定 ─────────────────────────────┐ │
│  │                                         │ │
│  │  Gemini API Key                         │ │
│  │  [••••••••••••••••••••]  [驗證] ✓       │ │
│  │                                         │ │
│  │  Anthropic API Key                      │ │
│  │  [••••••••••••••••••••]  [驗證] ✓       │ │
│  │                                         │ │
│  └─────────────────────────────────────────┘ │
│                                              │
│  ┌─ 語言設定 ─────────────────────────────┐ │
│  │                                         │ │
│  │  主要語言: [繁體中文 ▼]                 │ │
│  │  次要語言: [English  ▼]                 │ │
│  │  ☑ 啟用混語模式                         │ │
│  │                                         │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

#### 7.2.4 歷史記錄視窗

```
┌────────────────────────────────────────────────┐
│  歷史記錄                              ✕      │
│  ──────────────────────────────────────────── │
│  🔍 [搜尋歷史記錄...]                         │
│                                                │
│  今天                                          │
│  ┌──────────────────────────────────────────┐  │
│  │ 14:32  Slack                             │  │
│  │ 我想要預訂明天下午三點的會議室。          │  │
│  │                                 [複製]   │  │
│  ├──────────────────────────────────────────┤  │
│  │ 14:15  Gmail                             │  │
│  │ 您好，附件是本月的報告，請查收。          │  │
│  │                                 [複製]   │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  昨天                                          │
│  ┌──────────────────────────────────────────┐  │
│  │ ...                                      │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

---

## 8. 資料流程

### 8.1 核心流程：語音輸入

```
使用者                 App                    Gemini API          Claude API
  │                     │                        │                    │
  │ ─ 按下 Fn 鍵 ────→ │                        │                    │
  │                     │ ─ 開始擷取音訊          │                    │
  │                     │ ─ 顯示浮動面板          │                    │
  │ ─ 說話 ──────────→ │                        │                    │
  │                     │ ─ 串流音訊 ──────────→ │                    │
  │                     │ ←── 即時轉錄文字 ────── │                    │
  │                     │ ─ 更新浮動面板          │                    │
  │ ─ 放開 Fn 鍵 ────→ │                        │                    │
  │                     │ ─ 停止擷取              │                    │
  │                     │ ─ 取得最終轉錄 ───────→ │                    │
  │                     │ ←── 最終轉錄文字 ─────── │                    │
  │                     │                        │                    │
  │                     │ ─ 送出修正請求 ────────────────────────────→ │
  │                     │ ←── 修正後文字 ─────────────────────────────── │
  │                     │                        │                    │
  │                     │ ─ 注入文字至目標 App     │                    │
  │                     │ ─ 儲存歷史記錄          │                    │
  │                     │ ─ 顯示完成狀態          │                    │
  │ ←─ 文字已輸入 ──── │                        │                    │
```

### 8.2 核心流程：語音編輯

```
使用者                 App                    Gemini API          Claude API
  │                     │                        │                    │
  │ ─ 選取文字          │                        │                    │
  │ ─ 按下 ⌘⇧V ──────→ │                        │                    │
  │                     │ ─ 讀取選取文字          │                    │
  │                     │ ─ 開始擷取音訊          │                    │
  │ ─ 說出編輯指令 ──→ │                        │                    │
  │ ─ 放開 ⌘⇧V ──────→ │                        │                    │
  │                     │ ─ 送出音訊 ──────────→ │                    │
  │                     │ ←── 指令文字 ─────────── │                    │
  │                     │                        │                    │
  │                     │ ─ 送出 {原文+指令} ─────────────────────────→ │
  │                     │ ←── 修改後文字 ─────────────────────────────── │
  │                     │                        │                    │
  │                     │ ─ 替換選取文字          │                    │
  │ ←─ 文字已修改 ──── │                        │                    │
```

---

## 9. 權限需求

| 權限 | 用途 | 何時請求 |
|------|------|---------|
| 麥克風 (Microphone) | 擷取語音 | 首次使用語音輸入時 |
| 輔助使用 (Accessibility) | 全域快捷鍵、文字注入、前景 App 偵測 | 首次啟動時 |
| 網路 (Network) | 呼叫 Gemini / Anthropic API | 不需額外授權 |

---

## 10. 錯誤處理

| 情境 | 處理方式 | 使用者提示 |
|------|---------|-----------|
| 無麥克風權限 | 引導至系統偏好設定 | 「請在系統設定中允許麥克風存取」 |
| 無輔助使用權限 | 引導至系統偏好設定 | 「請在系統設定中允許輔助使用」 |
| Gemini API Key 無效 | 引導至設定頁面 | 「Gemini API Key 無效，請重新設定」 |
| Anthropic API Key 無效 | 引導至設定頁面 | 「Anthropic API Key 無效，請重新設定」 |
| API Rate Limit | Exponential backoff 重試 | 「API 忙碌中，正在重試...」 |
| 網路斷線 | 偵測網路狀態 | 「網路連線中斷，請檢查網路」 |
| 無法辨識語音 | 提示重新嘗試 | 「無法辨識，請再試一次」 |
| 文字注入失敗 | 改用剪貼簿方式 | 「已複製到剪貼簿，請手動貼上」 |

---

## 11. 專案檔案結構 (建議)

```
Typeless/
├── Typeless.xcodeproj
├── Typeless/
│   ├── App/
│   │   ├── TypelessApp.swift              # App 進入點
│   │   ├── AppDelegate.swift              # App 生命週期
│   │   └── AppState.swift                 # 全域狀態管理
│   │
│   ├── UI/
│   │   ├── FloatingPanel/
│   │   │   ├── FloatingPanelView.swift    # 浮動面板 UI
│   │   │   ├── WaveformView.swift         # 波形動畫
│   │   │   └── FloatingPanelViewModel.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift         # 設定視窗
│   │   │   ├── APISettingsView.swift      # API 設定頁
│   │   │   ├── LanguageSettingsView.swift # 語言設定頁
│   │   │   └── ShortcutSettingsView.swift # 快捷鍵設定頁
│   │   ├── History/
│   │   │   ├── HistoryView.swift          # 歷史記錄視窗
│   │   │   └── HistoryViewModel.swift
│   │   ├── Dictionary/
│   │   │   ├── DictionaryView.swift       # 詞典管理視窗
│   │   │   └── DictionaryViewModel.swift
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift          # 選單列
│   │   └── Onboarding/
│   │       └── OnboardingView.swift       # 首次使用引導
│   │
│   ├── Services/
│   │   ├── Audio/
│   │   │   ├── AudioCaptureManager.swift  # 音訊擷取
│   │   │   ├── AudioStreamEncoder.swift   # 音訊編碼
│   │   │   └── AudioLevelMonitor.swift    # 音量監測
│   │   ├── AI/
│   │   │   ├── GeminiSTTService.swift     # Gemini 語音轉文字
│   │   │   ├── ClaudeRefinementService.swift  # Claude 文字修正
│   │   │   ├── ClaudeEditService.swift    # Claude 語音編輯
│   │   │   ├── PromptManager.swift        # Prompt 管理
│   │   │   └── PipelineOrchestrator.swift # AI Pipeline 編排
│   │   ├── System/
│   │   │   ├── GlobalShortcutManager.swift    # 全域快捷鍵
│   │   │   ├── TextInjectionService.swift     # 文字注入
│   │   │   ├── AppContextDetector.swift       # App 語境偵測
│   │   │   └── AccessibilityBridge.swift      # 輔助使用封裝
│   │   └── Data/
│   │       ├── KeychainManager.swift      # Keychain 存取
│   │       ├── HistoryStore.swift         # 歷史記錄
│   │       ├── DictionaryStore.swift      # 個人詞典
│   │       └── PreferencesStore.swift     # 偏好設定
│   │
│   ├── Models/
│   │   ├── TranscriptionResult.swift      # 轉錄結果
│   │   ├── HistoryItem.swift              # 歷史項目
│   │   ├── DictionaryEntry.swift          # 詞典項目
│   │   └── AppContext.swift               # App 語境
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets                # 圖片資源
│   │   └── Sounds/                        # 音效檔案
│   │       ├── start_recording.aiff
│   │       └── stop_recording.aiff
│   │
│   └── Info.plist
│
├── TypelessTests/
│   └── ...
│
└── docs/
    └── SRS.md
```

---

## 12. 開發里程碑

| Phase | 里程碑 | 內容 | 預估時間 |
|-------|--------|------|---------|
| Phase 1 | **MVP — 基礎語音輸入** | 音訊擷取 + Gemini STT + Claude 修正 + 文字注入 | — |
| Phase 2 | **語音編輯** | Speak-to-Edit 功能 + App 語境偵測 | — |
| Phase 3 | **完善體驗** | 個人詞典 + 歷史記錄 + 自動格式化 | — |
| Phase 4 | **進階功能** | Markdown 支援 + 風格自訂 + Onboarding | — |

---

## 13. 附錄

### 13.1 Prompt 模板一覽

| Prompt | 用途 | 輸入 | 輸出 |
|--------|------|------|------|
| Refinement Prompt | 語音轉文字後修正 | 原始轉錄文字 + 個人詞典 | 修正後文字 |
| Edit Prompt | 語音指令編輯 | 選取文字 + 語音指令 | 修改後文字 |
| Format Prompt | 自動格式化 | 文字 + 格式偏好 | 格式化後文字 |
| Context Prompt | App 語境調整 | 文字 + App 名稱 | 調整語氣後文字 |

### 13.2 支援的 App 語境對照表

| App | 語境類型 | 預設語氣 |
|-----|---------|---------|
| Slack | 即時通訊 | 輕鬆口語 |
| Discord | 即時通訊 | 輕鬆口語 |
| Gmail | 電子郵件 | 正式書面 |
| Outlook | 電子郵件 | 正式書面 |
| Notion | 筆記 | 簡潔條理 |
| Apple Notes | 筆記 | 簡潔條理 |
| VS Code | 開發 | 技術描述 |
| Google Docs | 文件 | 書面正式 |
| Pages | 文件 | 書面正式 |
| iMessage | 訊息 | 輕鬆口語 |
| LINE | 訊息 | 輕鬆口語 |

---

> **文件結束**
> 版本 1.0.0 | 2026-02-12
