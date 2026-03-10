//
//  AppMonitor.swift
//  TypeAhead
//

import AppKit
import Combine

@MainActor
class AppMonitor: ObservableObject {

    @Published var isEnabled = {
        UserDefaults.standard.register(defaults: ["isEnabled": true])
        return UserDefaults.standard.bool(forKey: "isEnabled")
    }() {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            if isEnabled {
                keyboardMonitor.start()
            } else {
                keyboardMonitor.stop()
                suggestionPanel.hide()
                wordBuffer.reset()
            }
        }
    }

    @Published var tapActive = false

    let snippetStore = SnippetStore()

    private var wordBuffer: WordBuffer
    private let keyboardMonitor: KeyboardMonitor
    private let suggestionPanel = SuggestionPanel()
    private let cursorTracker = CursorTracker()
    private let textInjector = TextInjector()
    private let placeholderPanel = PlaceholderFillPanel()
    private var cancellables = Set<AnyCancellable>()
    private var lastExpansionLength = 0
    private var watchdog: AnyCancellable?
    private let hotkeyManager = HotkeyManager()

    init() {
        UserDefaults.standard.register(defaults: [
            "triggerPrefix": "//",
            "showOnPrefix": true,
            "searchExpansions": true,
            "sortByRecency": false
        ])
        let buffer = WordBuffer()
        let monitor = KeyboardMonitor(wordBuffer: buffer)
        self.wordBuffer = buffer
        self.keyboardMonitor = monitor
        buffer.triggerPrefix = Self.storedTriggerPrefix()
        buffer.showOnPrefix = UserDefaults.standard.bool(forKey: "showOnPrefix")
        buffer.searchExpansions = UserDefaults.standard.bool(forKey: "searchExpansions")
        buffer.sortByRecency = UserDefaults.standard.bool(forKey: "sortByRecency")
        setupCallbacks()
        if isEnabled { keyboardMonitor.start() }
        startWatchdog()
        registerHotkey()
    }

    private static func storedTriggerPrefix() -> String {
        let raw = UserDefaults.standard.string(forKey: "triggerPrefix") ?? "//"
        return raw.isEmpty ? "//" : raw
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        let keyCode  = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        hotkeyManager.register(keyCode: keyCode == 0 ? -1 : keyCode, modifiers: modifiers)
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        watchdog = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, isEnabled, !tapActive else { return }
                print("[TypeAhead] Watchdog: tap is dead — restarting...")
                keyboardMonitor.start()
            }
    }

    // MARK: - Wiring

    private func setupCallbacks() {
        wordBuffer.onMatchesChanged = { [weak self] matches, buffer in
            if !buffer.isEmpty { self?.lastExpansionLength = 0 }
            self?.handleMatchesChanged(matches)
        }
        keyboardMonitor.onBackspace = { [weak self] in
            guard let self, lastExpansionLength > 0 else { return false }
            let len = lastExpansionLength
            lastExpansionLength = 0
            textInjector.inject(expansion: "", replacingPrefixOfLength: len)
            return true
        }
        keyboardMonitor.isPopupVisible = { [weak self] in
            self?.suggestionPanel.isVisible ?? false
        }
        keyboardMonitor.onSpecialKey = { [weak self] key in
            self?.handleSpecialKey(key) ?? false
        }
        keyboardMonitor.onTapStateChanged = { [weak self] active in
            self?.tapActive = active
            if !active { self?.isEnabled = false }
        }

        // Keep word buffer in sync with snippet store
        snippetStore.$snippets
            .sink { [weak self] snippets in self?.wordBuffer.updateSnippets(snippets) }
            .store(in: &cancellables)

        // Reset buffer when any of our windows gains focus (e.g. Manage Snippets opens)
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.wordBuffer.reset()
                self?.suggestionPanel.hide()
            }
            .store(in: &cancellables)

        // Sync trigger prefix from UserDefaults whenever it changes (e.g. from SnippetsView)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let prefix = Self.storedTriggerPrefix()
                if wordBuffer.triggerPrefix != prefix {
                    wordBuffer.triggerPrefix = prefix
                    wordBuffer.reset()
                    print("[TypeAhead] Trigger prefix updated to '\(prefix)'")
                }
                wordBuffer.showOnPrefix = UserDefaults.standard.bool(forKey: "showOnPrefix")
                wordBuffer.searchExpansions = UserDefaults.standard.bool(forKey: "searchExpansions")
                wordBuffer.sortByRecency = UserDefaults.standard.bool(forKey: "sortByRecency")
                registerHotkey()
            }
            .store(in: &cancellables)
    }

    // MARK: - Popup

    private func handleMatchesChanged(_ matches: [Snippet]) {
        // Suppress popup when one of our own windows is focused (e.g. Manage Snippets)
        if NSApp.keyWindow != nil {
            suggestionPanel.hide()
            return
        }
        if matches.isEmpty {
            suggestionPanel.hide()
        } else {
            suggestionPanel.show(matches: matches, near: cursorTracker.getCursorRect())
        }
    }

    private func handleSpecialKey(_ key: SpecialKey) -> Bool {
        switch key {
        case .tab, .returnKey: acceptSuggestion(); return true
        case .escape:          wordBuffer.reset(); suggestionPanel.hide(); return true
        case .arrowDown:       suggestionPanel.selectNext(); return true
        case .arrowUp:         suggestionPanel.selectPrevious(); return true
        }
    }

    private func acceptSuggestion() {
        guard let snippet = suggestionPanel.selectedMatch else { return }
        let prefixLen = wordBuffer.bufferLength
        wordBuffer.reset()
        suggestionPanel.hide()

        let placeholders = parsePlaceholders(snippet.expansion)
        if !placeholders.isEmpty {
            placeholderPanel.show(
                snippetName: snippet.displayName,
                placeholders: placeholders,
                near: cursorTracker.getCursorRect()
            ) { [weak self] values in
                guard let self else { return }
                let filled = self.fillPlaceholders(snippet.expansion, placeholders: placeholders, values: values)
                self.injectExpansion(filled, isShell: snippet.isShellCommand, prefixLen: prefixLen)
            }
        } else {
            injectExpansion(snippet.expansion, isShell: snippet.isShellCommand, prefixLen: prefixLen)
        }
    }

    private func injectExpansion(_ expansion: String, isShell: Bool, prefixLen: Int) {
        if isShell {
            let output = runShellCommand(expansion) ?? ""
            textInjector.inject(expansion: output, replacingPrefixOfLength: prefixLen)
            lastExpansionLength = output.count
        } else {
            textInjector.inject(expansion: expansion, replacingPrefixOfLength: prefixLen)
            lastExpansionLength = expansion.count
        }
    }

    private func parsePlaceholders(_ expansion: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "\\{([^}]+)\\}")
        let range = NSRange(expansion.startIndex..., in: expansion)
        var seen = Set<String>()
        var result: [String] = []
        for match in pattern.matches(in: expansion, range: range) {
            if let r = Range(match.range(at: 1), in: expansion) {
                let name = String(expansion[r])
                if seen.insert(name).inserted { result.append(name) }
            }
        }
        return result
    }

    private func fillPlaceholders(_ expansion: String, placeholders: [String], values: [String]) -> String {
        var result = expansion
        for (ph, val) in zip(placeholders, values) {
            result = result.replacingOccurrences(of: "{\(ph)}", with: val)
        }
        return result
    }

    /// Runs a shell command synchronously (max 3s) and returns trimmed stdout.
    /// ⚠️ Experimental — blocks the main thread briefly.
    private func runShellCommand(_ command: String) -> String? {
        let process = Process()
        let outPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = outPipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        // Wait up to 3 seconds on a background thread
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { process.waitUntilExit(); sema.signal() }
        if sema.wait(timeout: .now() + 3) == .timedOut { process.terminate() }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
