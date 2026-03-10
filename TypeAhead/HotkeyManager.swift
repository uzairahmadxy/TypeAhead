//
//  HotkeyManager.swift
//  TypeAhead
//

import AppKit

extension Notification.Name {
    static let openManageSnippets = Notification.Name("TypeAheadOpenManageSnippets")
}

/// Registers and listens for a global keyboard shortcut to open Manage Snippets.
class HotkeyManager {
    private var monitor: Any?

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        guard keyCode >= 0 else { return }   // -1 = no hotkey set
        let targetCode = UInt16(keyCode)
        let targetMods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
            .intersection(.deviceIndependentFlagsMask)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == targetCode, mods == targetMods else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openManageSnippets, object: nil)
            }
        }
    }

    func unregister() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Key Recorder Button

import SwiftUI

/// A button that shows the current shortcut and records a new one when clicked.
struct KeyRecorderButton: View {
    private let keyCodeKey: String
    private let modifiersKey: String
    private let labelKey: String

    @AppStorage private var keyCode: Int
    @AppStorage private var modifiers: Int
    @AppStorage private var label: String

    init(keyCodeKey: String = "hotkeyKeyCode",
         modifiersKey: String = "hotkeyModifiers",
         labelKey: String = "hotkeyLabel") {
        self.keyCodeKey = keyCodeKey
        self.modifiersKey = modifiersKey
        self.labelKey = labelKey
        _keyCode   = AppStorage(wrappedValue: -1, keyCodeKey)
        _modifiers = AppStorage(wrappedValue: 0,  modifiersKey)
        _label     = AppStorage(wrappedValue: "", labelKey)
    }

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Press shortcut…" : (label.isEmpty ? "Click to set" : label))
                .frame(minWidth: 110, alignment: .center)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
        .onDisappear { stopRecording() }

        if !label.isEmpty && !isRecording {
            Button {
                keyCode = -1; modifiers = 0; label = ""
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear shortcut")
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { self.stopRecording(); return nil } // Escape = cancel
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !mods.isEmpty else { return event } // require at least one modifier
            self.keyCode    = Int(event.keyCode)
            self.modifiers  = Int(mods.rawValue)
            self.label      = Self.format(event: event)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private static func format(event: NSEvent) -> String {
        let mods  = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        s += (event.charactersIgnoringModifiers ?? "").uppercased()
        return s
    }
}
