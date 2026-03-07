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
    /// Read synchronously from the main-thread event tap callback.
    var isPopupVisible: () -> Bool = { false }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(wordBuffer: WordBuffer) {
        self.wordBuffer = wordBuffer
    }

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system permission prompt. Returns whether access is already granted.
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        guard eventTap == nil else { return }

        guard Self.isAccessibilityGranted() else {
            print("[TypeAhead] ⚠️  Accessibility permission not granted — requesting now.")
            Self.requestAccessibilityPermission()
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // defaultTap so we can consume Tab/Esc
            eventsOfInterest: eventMask,
            callback: { (_, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard type == .keyDown, let ptr = userInfo else {
                    return Unmanaged.passRetained(event)
                }

                // Skip events we injected ourselves to avoid re-entrancy
                if event.getIntegerValueField(.eventSourceUserData) == TextInjector.markerValue {
                    return Unmanaged.passRetained(event)
                }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ptr).takeUnretainedValue()

                // The tap fires on the main run loop thread — safe to use MainActor state.
                return MainActor.assumeIsolated {
                    monitor.handleEvent(event)
                }
            },
            userInfo: selfPtr
        ) else {
            print("[TypeAhead] ⚠️  Failed to create event tap.")
            print("[TypeAhead]    System Settings → Privacy & Security → Accessibility → grant TypeAhead access, then relaunch.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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
        print("[TypeAhead] Keyboard monitoring stopped.")
    }

    // MARK: - Private (called on main thread via MainActor.assumeIsolated)

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Intercept navigation keys when the popup is visible
        if isPopupVisible() {
            let specialKey: SpecialKey? = switch keyCode {
                case 0x30: .tab
                case 0x24: .returnKey
                case 0x35: .escape
                case 0x7D: .arrowDown
                case 0x7E: .arrowUp
                default:   nil
            }
            if let specialKey, onSpecialKey?(specialKey) == true {
                return nil  // consume the event
            }
        }

        // Regular character — feed to word buffer
        if let nsEvent = NSEvent(cgEvent: event),
           let chars = nsEvent.characters, !chars.isEmpty {
            for char in chars {
                wordBuffer.process(character: char)
            }
        }

        return Unmanaged.passRetained(event)
    }
}
