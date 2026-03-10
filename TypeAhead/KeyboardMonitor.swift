//
//  KeyboardMonitor.swift
//  TypeAhead
//

import AppKit
import CoreGraphics

enum SpecialKey { case tab, returnKey, escape, arrowUp, arrowDown }

class KeyboardMonitor {

    let wordBuffer: WordBuffer

    /// Called synchronously on the main thread from the event tap.
    /// Return true to consume (drop) the event, false to pass it through.
    var onSpecialKey: ((SpecialKey) -> Bool)?

    /// Returns whether the suggestion popup is currently visible.
    var isPopupVisible: () -> Bool = { false }

    /// Called when the tap is successfully created or torn down.
    var onTapStateChanged: ((Bool) -> Void)?

    /// Called on backspace. Return true to consume the event (undo last expansion).
    var onBackspace: (() -> Bool)?

    /// When non-nil, the monitor is in fill mode: printable characters are consumed
    /// and forwarded here instead of the word buffer.
    var onFillCharacter: ((Character) -> Void)?

    var isTapActive: Bool { eventTap != nil }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(wordBuffer: WordBuffer) {
        self.wordBuffer = wordBuffer
    }

    // MARK: - Permission helpers

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func isInputMonitoringGranted() -> Bool {
        CGPreflightListenEventAccess()
    }

    // MARK: - Tap lifecycle

    func start() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (_, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard type == .keyDown, let ptr = userInfo else {
                    return Unmanaged.passRetained(event)
                }
                if event.getIntegerValueField(.eventSourceUserData) == TextInjector.markerValue {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ptr).takeUnretainedValue()
                return MainActor.assumeIsolated { monitor.handleEvent(event) }
            },
            userInfo: selfPtr
        ) else {
            if !Self.isAccessibilityGranted() {
                print("[TypeAhead] ⚠️  Accessibility permission missing — requesting.")
                Self.requestAccessibilityPermission()
            } else {
                print("[TypeAhead] ⚠️  Tap failed despite Accessibility being granted.")
                print("[TypeAhead]    Root cause: Input Monitoring permission is likely missing.")
                print("[TypeAhead]    → System Settings › Privacy & Security › Input Monitoring")
                print("[TypeAhead]      Add TypeAhead there and enable it, then retry the toggle.")
            }
            onTapStateChanged?(false)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onTapStateChanged?(true)
        print("[TypeAhead] ✅ Keyboard monitoring started.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        onTapStateChanged?(false)
        print("[TypeAhead] Keyboard monitoring stopped.")
    }

    // MARK: - Event handling (runs on main thread)

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let inFillMode = onFillCharacter != nil

        // Special keys: intercept when popup visible or in fill mode
        if isPopupVisible() || inFillMode {
            let specialKey: SpecialKey? = switch keyCode {
                case 0x30: .tab
                case 0x24: .returnKey
                case 0x35: .escape
                case 0x7D: .arrowDown
                case 0x7E: .arrowUp
                default:   nil
            }
            if let specialKey, onSpecialKey?(specialKey) == true {
                return nil
            }
        }

        // Backspace: fill mode delete or undo last expansion
        if keyCode == 0x33, onBackspace?() == true {
            return nil
        }

        // Fill mode: consume printable characters and route to fill handler
        if inFillMode,
           let nsEvent = NSEvent(cgEvent: event),
           let chars = nsEvent.characters, !chars.isEmpty {
            let printable = chars.filter { $0 >= " " }
            if !printable.isEmpty {
                for char in printable { onFillCharacter?(char) }
                return nil
            }
        }

        if let nsEvent = NSEvent(cgEvent: event),
           let chars = nsEvent.characters, !chars.isEmpty {
            for char in chars { wordBuffer.process(character: char) }
        }

        return Unmanaged.passRetained(event)
    }
}
